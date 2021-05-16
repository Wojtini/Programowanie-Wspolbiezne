with Ada.Text_IO; use ADA.Text_IO;
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Command_Line;
with Ada.Strings;
with ada.numerics.discrete_random;
with Ada.Containers; use Ada.Containers;
with Ada.Containers.Vectors;

procedure main is
    No_of_nodes : Integer := Integer'Value(Ada.Command_Line.Argument(1));
    No_of_shortcuts : Integer := Integer'Value(Ada.Command_Line.Argument(2));

    randomNumber : Integer := 0;
    randomNumber2 : Integer := 0;
    bulik : Integer := 0;
    a : Integer := 0;

    type integerArray is array (Integer range <>) of Natural;
    package Integer_Vectors is new Ada.Containers.Vectors(Index_Type   => Natural, Element_Type => Integer);
    use Integer_Vectors;

    --rng
    subtype Rand_Range is Integer range 0 .. No_of_nodes-1;
    package Rand_Int is new ada.numerics.discrete_random(Rand_Range);
    use Rand_Int;
    gen : Generator;

    -- Node Info struct
    type NodeInfo is record
      id : Integer;
      nextNodes : Vector;
      handledPacketsVector : Vector;
    end record;
    type NodeInfoPtr is access NodeInfo;

    --Print Server
    task Printer is
      entry print(text: String);
      entry exterminate;
    end Printer;
    task body Printer is
    begin
      loop
        select
            accept print(text: String) do
              Put_Line(text);
            end print;
          or
            accept exterminate do
              null;
            end exterminate;
            exit;
        end select;
      end loop;
    end Printer;

    --Counter
    task counter is
      entry input (val: Integer);
      entry getEnd (temp: out Integer);
      entry exterminate;
    end counter;
    task body counter is
    c : Integer := 0;
    begin
      loop
        select
          accept input (val: Integer) do
            c := c + val;
            -- Printer.print("PC:" & Integer'Image(c));
          end input;
        or
          delay 25.0;
          accept getEnd(temp : out Integer) do
            temp := 0;
          end getEnd;
          accept exterminate do
            null;
          end exterminate;
          exit;
        end select;
      end loop;
    end counter;

    -- R_j
    type R_j is record
      j : Integer;
      cost : Integer;
      nexthop : Integer;
      changed : Boolean;
    end record;
    type R_j_Ptr is access R_j;

    type R_j_Array is array (0..No_of_nodes-1) of R_j;

    type Packet is Record
      sender: Integer;
      size: Integer;
      arr: R_j_Array;
    end record;
    type PacketPtr is access Packet;

    protected type RoutingTable is

       function Get(index: Integer) return R_j;
       procedure Set(value: R_j);
       procedure ChangeFlag(index: Integer; change: Boolean); --wyglada na groznie i tak jest
       procedure InitValues(n: NodeInfoPtr); --wyglada na groznie i tak jest
       entry BetterGet (index: Integer; rj : out R_j);

    private
       arr : R_j_Array;
    end RoutingTable;

    protected body RoutingTable is

       entry BetterGet (index: Integer; rj : out R_j)
        when true is
       begin
          rj := arr(index);
          arr(index).changed := false;
       end BetterGet;

       function Get(index: Integer) return R_j is -- Get Record
       begin
         -- arr(index).changed := false; jakos to trzeba zrobic
         return arr(index);
       end Get;

       procedure ChangeFlag(index: Integer; change: Boolean) is --wyglada na groznie i tak jest
       begin
         counter.input(-1); -- change zawsze na false
         arr(index).changed := change;
       end ChangeFlag;

       procedure Set(value: R_j) is
       begin
         -- Put_Line("XASDASDASDSAKJDHAKJSD");
         arr(value.j) := value;
         counter.input(1);
         arr(value.j).changed := true;
       end Set;

       procedure InitValues(n: NodeInfoPtr) is
       begin
         for I in 0 .. No_of_nodes-1 loop
           arr(I).j := I;
           if n.id > I then
             arr(I).cost := n.id - I;
             arr(I).nexthop := n.id - 1;
           else
             arr(I).cost := I - n.id;
             arr(I).nexthop := n.id + 1;
           end if;
           if n.id = I then
             arr(I).changed := false;
           else

             counter.input(1);
             arr(I).changed := true;
           end if;
         end loop;
         --skroty
         for E of n.nextNodes loop
           --Put(Integer'Image(E) & ", ");
           arr(E).cost := 1;
           arr(E).nexthop := E;
         end loop;
       end InitValues;

    end RoutingTable;

    type RoutingArray is array (0..No_of_nodes-1) of RoutingTable;
    routesArray : RoutingArray;


    -- type RoutingArrayThread is array (0..No_of_nodes-1) of RoutingTableThread;
    -- routesArrayThread : RoutingArrayThread;

    --receiver p1
    task type Receiver is
      entry nodeInput(n: NodeInfoPtr);
      entry packetInput(p: Packet);
      entry exterminate;
    end Receiver;

    type ReceiverArray is array (0..No_of_nodes-1) of Receiver;
    rArray : ReceiverArray;

    -- Sender
    task type Sender is
      entry nodeInput(n: NodeInfoPtr);
      entry exterminate;
      entry start;
    end Sender;

    task body Sender is
    ni : NodeInfoPtr;
    new_Packet : Packet;
    curr: R_j;
    counter: Integer := 0;
    begin
      accept nodeInput(n: NodeInfoPtr) do
        ni := n;
      end nodeInput;

      accept start do
        null;
      end start;

      loop
        select
          accept exterminate do
            null;
          end exterminate;
          exit;
        or
          delay (random(gen) + 2)*1.2; -- budz sie co jakis czas
          new_Packet.sender := ni.id;
          new_Packet.size := 0;
          for I in 0..No_of_nodes-1 loop
            --Biore informacje
            if ni.id = 4 then
              null;
              -- Printer.print(Integer'Image(ni.id) & " SENDER OPERUJE NA ROUTES ARRAY ");
            end if;
            -- curr := routesArray(ni.id).Get(I);          --    nie ma prawa sie udac
            routesArray(ni.id).BetterGet(I,curr);
            -- routesArrayThread(ni.id).Get(I);          --    thread
            -- routesArrayThread(ni.id).GetOut(curr);
            if curr.changed then
              -- routesArray(ni.id).ChangeFlag(I,false);   --    nie ma prawa sie udac
              new_Packet.arr(new_Packet.size) := curr;
              new_Packet.size := new_Packet.size + 1;
            end if;
          end loop;
          --wyslij
          if new_Packet.size > 0 then
            counter := counter + 1;
            -- Put_Line(Integer'Image(ni.id) & " wysyla paczke ");
            for E of ni.nextNodes loop
              rArray(E).packetInput(new_Packet);
              -- Put_Line(Integer'Image(ni.id) & "wyslalem");
            end loop;
          else
            null;
            Put_Line(Integer'Image(ni.id) & " juz nic nie ma");
          end if;
        end select;
      end loop;
    end Sender;

    -- Receiver p2

    task body Receiver is
    ni : NodeInfoPtr;
    newly : R_j;
    curr: R_j;
    temp_packet: Packet;
    begin
      accept nodeInput(n: NodeInfoPtr) do
        ni := n;
      end nodeInput;

      loop
        select
          accept exterminate do
            null;
          end exterminate;
          exit;
        or
          accept packetInput(p: Packet) do
            temp_packet := p;
          end packetInput;
          for I in 0 .. temp_packet.size-1 loop
            null;
            newly := temp_packet.arr(I);
            newly.cost := newly.cost + 1;
            newly.nexthop := temp_packet.sender;
            newly.changed := true;
            curr := routesArray(ni.id).Get(newly.j);
            if newly.cost < curr.cost then
              Printer.print(Integer'Image(ni.id) & " zrobil zmiane drogi do: " & Integer'Image(newly.j) & " przez " & Integer'Image(newly.nexthop) & " koszt nowej drogi " & Integer'Image(newly.cost));
              routesArray(ni.id).Set(newly);
            end if;
          end loop;
        end select;
      end loop;

    end Receiver;

    type nodeArray is array (Integer range<>) of NodeInfoPtr;
    nodesAll : nodeArray(0..No_of_nodes);

    type SenderArray is array (0..No_of_nodes-1) of Sender;
    sArray : SenderArray;


begin
  -- Checks
  if(No_of_nodes<2) then
		Put_Line("too few nodes");
    Printer.exterminate;
		return;
	end if;
	if(No_of_shortcuts > (No_of_nodes-1)*(No_of_nodes/2)) then
		Put_Line("too much shortcuts");
    Printer.exterminate;
		return;
	end if;

  -- Creating nodes
  for I in 0 .. No_of_nodes-1 loop
    --Create node and set its variables
    nodesAll(I) := new NodeInfo;
    nodesAll(I).id := I;
    if I+1/=No_of_nodes then
      nodesAll(I).nextNodes.Append(I+1);
      -- nodesAll(I+1).nextNodes.Append(I);
    end if;

    rArray(I).nodeInput(nodesAll(I)); --przesyla node info
    sArray(I).nodeInput(nodesAll(I)); --przesyla node info
  end loop;

  -- Put_Line("Po stworzeniu nodow");
  --polaczenia w druga strone
  for I in 0 .. No_of_nodes-2 loop
    -- Put_Line("Test. " & Integer'Image(I+1) & Integer'Image(I));
    nodesAll(I+1).nextNodes.Append(I);
  end loop;


  --shortcuts
  reset(gen);
  for I in 0 .. No_of_shortcuts-1 loop
    randomNumber := random(gen);
    loop
      randomNumber2 := random(gen);
      --swapPos
      if randomNumber2/=randomNumber and randomNumber2/=No_of_nodes then
        -- Check if route already exists
        bulik := 0;
        for E of nodesAll(randomNumber).nextNodes loop
          if E = randomNumber2 then
            bulik := 1;
          end if;
        end loop;
        if bulik = 0 then
          nodesAll(randomNumber).nextNodes.Append(randomNumber2);
          nodesAll(randomNumber2).nextNodes.Append(randomNumber);
          exit;
        end if;
      end if;
    end loop;
    -- Put_Line("nowy skrot: " & Integer'Image(randomNumber) & " do " & Integer'Image(randomNumber2));
  end loop;
  -- nodesAll(0).nextNodes.Append(5);
  -- nodesAll(5).nextNodes.Append(0);
  --show routes
  for I in 0 .. No_of_nodes-1 loop
    Put("Node no. " & Integer'Image(I) & " routes ::::::: ");
    for E of nodesAll(I).nextNodes loop
      Put(Integer'Image(E) & ", ");
    end loop;
    New_Line;
  end loop;


  --wyslij do routing table po stworzeniu skrotow
  for I in 0 .. No_of_nodes-1 loop
    routesArray(I).InitValues(nodesAll(I));
    -- routesArrayThread(I).InitValues(nodesAll(I));
  end loop;

  --Start
  for I in 0 .. No_of_nodes-1 loop
    sArray(I).start; --start
  end loop;

  counter.getEnd(a);
  Put_Line("Konczenie dzialania symulacji");
  --Eksterminacja
  for I in 0 .. No_of_nodes-1 loop
    -- Put_Line("wylaczam " & Integer'Image(I));
    rArray(I).exterminate;
    sArray(I).exterminate;
  end loop;
  counter.exterminate;
  Printer.exterminate;
end main;
