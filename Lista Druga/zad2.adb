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
    No_of_antishortcuts : Integer := Integer'Value(Ada.Command_Line.Argument(3));
    No_of_packets : Integer := Integer'Value(Ada.Command_Line.Argument(4));
    Value_of_ttl : Integer := Integer'Value(Ada.Command_Line.Argument(5));

    a : Integer := 0; -- pom to get value in ending
    randomNumber : Integer := 0;
    randomNumber2 : Integer := 0;
    bulik : Integer := 0;

    type integerArray is array (Integer range <>) of Natural;
    package Integer_Vectors is new Ada.Containers.Vectors(Index_Type   => Natural, Element_Type => Integer);
    use Integer_Vectors;

    --rng
    subtype Rand_Range is Integer range 0 .. No_of_nodes-1;
    package Rand_Int is new ada.numerics.discrete_random(Rand_Range);
    use Rand_Int;
    gen : Generator;

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

    task PacketCounter is
      entry lastNodeId (id: Integer);
      entry getEnd (temp: out Integer);
      entry packetInput(pid: Integer);
      entry exterminate;
    end PacketCounter;
    task body PacketCounter is
    packetCounts : Integer;
    lastNode : Integer;
    doEnd : Boolean;
    begin
      accept lastNodeId(id: Integer) do
        lastNode := id;
      end lastNodeId;

      packetCounts := 0;
      doEnd := false;
      loop
        select
          accept packetInput(pid: Integer) do
            if pid > 0 then
              packetCounts := packetCounts + 1;
              if pid = lastNode then
                doEnd := true;
              end if;
            else
              packetCounts := packetCounts - 1;
            end if;
            -- Printer.print("PC:" & Integer'Image(packetCounts));
          end packetInput;
        or
          accept exterminate do
            null;
          end exterminate;
          exit;
        end select;

        if doEnd and packetCounts=0 then
          -- Printer.print("PC:GG");
          accept getEnd(temp : out Integer) do
            temp := 0;
          end getEnd;
        end if;
      end loop;
    end PacketCounter;

    type Packet is record
      id : Integer;
      visitedNodesVector : Vector;
      ttl: Integer;
    end record;
    type PacketPtr is access Packet;

    type NodeInfo is record
      id : Integer;
      nextNodes : Vector;
      handledPacketsVector : Vector;
    end record;
    type NodeInfoPtr is access NodeInfo;

    type packetArray is array (Integer range<>) of PacketPtr;
    type nodeArray is array (Integer range<>) of NodeInfoPtr;

    task type Tasker is
        -- entry getEnd (temp: out Integer);
        entry nodeInput(n: NodeInfoPtr);
        entry packetInput(p: PacketPtr);
        entry exterminate;
        entry setupTrap;
    end Tasker;

    type taskArray is array (0..No_of_nodes-1) of Tasker;
    a1 : taskArray;

    packetsAll : packetArray(0..No_of_packets);
    nodesAll : nodeArray(0..No_of_nodes);

    task body Tasker is
    ni : NodeInfoPtr;
    pom : PacketPtr;
    rand : Integer;
    packetReceived : Boolean;
    trap : Boolean;
    begin
        trap := false;
        accept nodeInput(n: NodeInfoPtr) do
          ni := n;
        end nodeInput;
        for I in 1 .. No_of_nodes loop
          null;
        end loop;
        loop
          packetReceived := false;
          --Put_Line(Integer'Image(ni.id) & " Czeka");
          select
            accept packetInput(p: PacketPtr) do
              --saving in history
              p.visitedNodesVector.Append(ni.id);
              ni.handledPacketsVector.Append(p.id);
              pom := p;
              packetReceived := true;
              -- if trap=false then
              --   packetReceived := true; -- wyslij dalej
              -- else
              --   Printer.print("Pakiet: " & Integer'Image(p.id) & " umarl w wierzcholku " & Integer'Image(ni.id));
              --   PacketCounter.packetInput(-1); -- pakiet umarl
              -- end if;
            end packetInput;
          or
            accept exterminate do
              null;
            --accept, do nothing and exit loop causing to end task
            end exterminate;
            exit;
          or
            accept setupTrap do
              Printer.print("Zalozono polapke w wierzcholku nr: " & Integer'Image(ni.id));
              trap := true;
            end setupTrap;
          end select;
          --Wysyla do nastepnego, mozna usunac warunek (patrz killer)
          if packetReceived then
            if trap=true then
              Printer.print("Pakiet: " & Integer'Image(pom.id) & " zostal zlapany przez klusownika w " & Integer'Image(ni.id));
              PacketCounter.packetInput(-1);
              trap := false;
            else
              if ni.id=No_of_nodes-1 then --jesli ostatni
                Printer.print("Pakiet " & Integer'Image(pom.id) & " zostal odebrany");
                PacketCounter.packetInput(-1);
              else

                pom.ttl := pom.ttl - 1; --jesli ttl juz padl
                if pom.ttl < 0 then
                  Printer.print("Pakiet: " & Integer'Image(pom.id) & " umarl w wierzcholku " & Integer'Image(ni.id));
                  PacketCounter.packetInput(-1);
                else
                  Printer.print("Pakiet: " & Integer'Image(pom.id) & " jest w wierzcholku " & Integer'Image(ni.id));
                  rand := random(gen) + 1;

                  rand := (rand) mod Integer(ni.nextNodes.Length);--ni.nextNodes.Length

                  delay (random(gen) + 1)*0.2; --czekaj losowy czas
                  a1(ni.nextNodes(rand)).packetInput(pom);
                end if;
              end if;
            end if;
          end if;
        end loop;
    end Tasker;

    task Killer is
      entry exterminate;
      entry start;
    end Killer;
    task body Killer is
    rand : Integer;
    begin
      accept start do
        null;
      end start;
      loop
        select
          accept exterminate do
            null;
          end exterminate;
          -- Put_Line("Killer wychodzi");
          exit;
        or
            delay 2.0;
            rand := random(gen) + 3;
            delay rand*0.2;
            --get random node
            rand := random(gen) + 1;
            rand := rand mod (No_of_nodes-1);
            a1(rand).setupTrap;
        end select;
      end loop;
    end Killer;

begin
  if(No_of_nodes<2) then
		Put_Line("too few nodes");
    Printer.exterminate;
    PacketCounter.exterminate;
    Killer.exterminate;
		return;
	end if;
	if(No_of_shortcuts*2 > No_of_nodes) then
		Put_Line("too much shortcuts");
    Printer.exterminate;
    PacketCounter.exterminate;
    Killer.exterminate;
		return;
	end if;
	if (No_of_antishortcuts)*2 > No_of_nodes then
		Put_Line("too much (anti)shortcuts");
    Printer.exterminate;
    PacketCounter.exterminate;
    Killer.exterminate;
		return;
	end if;
	if No_of_packets = 0 then
		Put_Line("no packets");
    Printer.exterminate;
    PacketCounter.exterminate;
    Killer.exterminate;
		return;
	end if;


  for I in 0 .. No_of_nodes-1 loop
    --Create node and set its variables
    nodesAll(I) := new NodeInfo;
    nodesAll(I).id := I;
    if I+1/=No_of_nodes then
      nodesAll(I).nextNodes.Append(I+1);
    end if;

    a1(I).nodeInput(nodesAll(I));
    null;
  end loop;

  --shortcuts
  reset(gen);
  for I in 0 .. No_of_shortcuts-1 loop
    randomNumber := random(gen);
    loop
      randomNumber2 := random(gen);
      --swapPos
      if randomNumber2 < randomNumber then
        randomNumber2 := randomNumber2 + randomNumber;
        randomNumber :=  randomNumber2 - randomNumber;
        randomNumber2 := randomNumber2 - randomNumber;
      end if;

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
          exit;
        end if;
      end if;
    end loop;
    -- Put_Line("nowy skrot: " & Integer'Image(randomNumber) & " do " & Integer'Image(randomNumber2));
  end loop;

  --antishortucts

  for I in 0 .. No_of_antishortcuts-1 loop
    randomNumber := random(gen);
    loop
      randomNumber2 := random(gen) mod (No_of_nodes-1);
      --swapPos
      if randomNumber2 > randomNumber then
        randomNumber2 := randomNumber2 + randomNumber;
        randomNumber :=  randomNumber2 - randomNumber;
        randomNumber2 := randomNumber2 - randomNumber;
      end if;

      if randomNumber2/=randomNumber then
        -- Check if route already exists
        bulik := 0;
        for E of nodesAll(randomNumber).nextNodes loop
          if E = randomNumber2 then
            bulik := 1;
          end if;
        end loop;
        if bulik = 0 then
          nodesAll(randomNumber).nextNodes.Append(randomNumber2);
          exit;
        end if;
      end if;
    end loop;
    -- Put_Line("nowy skrot: " & Integer'Image(randomNumber) & " do " & Integer'Image(randomNumber2));
  end loop;

  --display routes
  for I in 0 .. No_of_nodes-1 loop
    Put("Node no. " & Integer'Image(I) & " routes ::::::: ");
    for E of nodesAll(I).nextNodes loop
      Put(Integer'Image(E) & ", ");
    end loop;
    New_Line;
  end loop;

  PacketCounter.lastNodeId(No_of_packets);
  --start killer
  Killer.start;
  --sending packets
  for I in 1 .. No_of_packets loop
      --creating and setting packets
      packetsAll(I) := new Packet;
      packetsAll(I).id := I;
      packetsAll(I).ttl := Value_of_ttl;

      --Printer.print( " wysylam " & Integer'Image(I));
      PacketCounter.packetInput(I);
      a1(0).packetInput(packetsAll(I));
  end loop;

  Printer.print( "Czekam na info od ostatniego noda");
  PacketCounter.getEnd(a);
  Printer.print( "Wylaczam symulacje");

  --armagedon
  -- Put_Line("Wylaczam killer");
  Killer.exterminate; -- najpierw wylaczamy killera zeby nie przerwac mu interakcji z wierzcholkami
  for I in 0 .. No_of_nodes-1 loop
    -- Put_Line("wylaczam " & Integer'Image(I));
    a1(I).exterminate;
    null;
  end loop;
  -- Put_Line("Wylaczam printer");
  Printer.exterminate;
  -- Put_Line("Wylaczam packetcounter");
  PacketCounter.exterminate;
  --Statystyki

  Put_Line("Informacje wezlow");
  for I in 0 .. No_of_nodes-1 loop
    Put("Node no. " & Integer'Image(I) & "::::::: ");
    for E of nodesAll(I).handledPacketsVector loop
      Put(Integer'Image(E) & ", ");
      -- Put(Integer'Image(nodesAll(I).handledPackets(J)) & ", ");
    end loop;
    New_Line;
  end loop;

  --Packet Stat
  Put_Line("Informacje pakietow");
  for I in 1 .. No_of_packets loop
    Put("Packet no. " & Integer'Image(I) & "::::::: ");
    for E of packetsAll(I).visitedNodesVector loop
      Put(Integer'Image(E) & ", ");
      -- Put(Integer'Image(nodesAll(I).handledPackets(J)) & ", ");
    end loop;
    New_Line;
  end loop;
end main;
