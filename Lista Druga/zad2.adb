with Ada.Text_IO; use ADA.Text_IO;
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Command_Line;
with Ada.Strings;
with ada.numerics.discrete_random;

procedure main is
    No_of_nodes : Integer := Integer'Value(Ada.Command_Line.Argument(1));
    No_of_packets : Integer := Integer'Value(Ada.Command_Line.Argument(2));
    No_of_shortcuts : Integer := Integer'Value(Ada.Command_Line.Argument(3));

    a : Integer := 0; -- pom to get value in ending
    randomNumber : Integer := 0;
    randomNumber2 : Integer := 0;

    type integerArray is array (Integer range <>) of Natural;

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

    type Packet is record
      id : Integer;
      visitedNodes : integerArray(0..No_of_nodes-1);
    end record;
    type PacketPtr is access Packet;

    type NodeInfo is record
      id : Integer;
      handledPackets : integerArray(1..No_of_packets);
      nextNodes : integerArray(0..No_of_nodes-1);
    end record;
    type NodeInfoPtr is access NodeInfo;

    type packetArray is array (Integer range<>) of PacketPtr;
    type nodeArray is array (Integer range<>) of NodeInfoPtr;

    task type Tasker is
        entry getEnd (temp: out Integer);
        entry nodeInput(n: NodeInfoPtr);
        entry packetInput(p: PacketPtr);
        entry exterminate;
    end Tasker;

    type taskArray is array (0..No_of_nodes-1) of Tasker;
    a1 : taskArray;

    packetsAll : packetArray(0..No_of_packets);
    nodesAll : nodeArray(0..No_of_nodes);

    task body Tasker is
    ni : NodeInfoPtr;
    pom : PacketPtr;
    counter : Integer;
    rand : Integer;
    begin
        accept nodeInput(n: NodeInfoPtr) do
          ni := n;
        end nodeInput;
        for I in 1 .. No_of_nodes loop
          null;
        end loop;
        loop
          --Put_Line(Integer'Image(ni.id) & " Czeka");
          select
            accept packetInput(p: PacketPtr) do
              --saving in history
              p.visitedNodes(ni.id) := 1;
              ni.handledPackets(p.id) := 1;
              pom := p;
              if ni.id=No_of_nodes-1 and p.id=No_of_packets then
                  accept getEnd(temp : out Integer) do
                    temp := 0;
                  end getEnd;
                  null;
              end if;
              rand := random(gen) + 1;
              delay rand*0.2;
              -- for I in 1 .. No_of_nodes loop
              --   Put_Line(Integer'Image(arr1(I)));
              --   null;
              -- end loop;
            end packetInput;
          or
            accept exterminate do
              null;
            --accept, do nothing and exit loop causing to ending task
            end exterminate;
            exit;
          end select;
          --Wysyla do nastepnego - zmienic
          if ni.id /= No_of_nodes-1 then
            Printer.print("Pakiet: " & Integer'Image(pom.id) & " jest w wierzcholku " & Integer'Image(ni.id));
            rand := random(gen) + 1;
            counter := 0;
            loop
              -- Put_Line(Integer'Image(counter) & " he " & Integer'Image(rand));
              if ni.nextNodes(counter)=1 then
                rand := rand - 1;
                if rand=0 then
                  a1(counter).packetInput(pom);
                  exit;
                end if;
              end if;
              counter := (counter + 1) mod No_of_nodes;

            end loop;
          else
            Printer.print("Pakiet " & Integer'Image(pom.id) & " zostal odebrany");
          end if;

          --Old method to send to n+1 node
          -- if (ni.id + 1) mod No_of_nodes /= 0 then
          --   a1((ni.id + 1) mod No_of_nodes).packetInput(pom);
          -- end if;

        end loop;
    end Tasker;

begin
  for I in 0 .. No_of_nodes-1 loop
    --Create node and set its variables
    nodesAll(I) := new NodeInfo;
    nodesAll(I).id := I;
    for J in 1 .. No_of_packets loop
      nodesAll(I).handledPackets(J) := 0;
    end loop;
    for J in 0 .. No_of_nodes-1 loop
      nodesAll(I).nextNodes(J) := 0;
      --if next node then connect
      if I+1=J then
        nodesAll(I).nextNodes(J) := 1;
      end if;
    end loop;

    a1(I).nodeInput(nodesAll(I));
    null;
  end loop;

  --skroty
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
      if randomNumber2/=randomNumber and (randomNumber2-1)/=randomNumber then
        if nodesAll(randomNumber).nextNodes(randomNumber2) = 0 then
          nodesAll(randomNumber).nextNodes(randomNumber2) := 1;
          exit;
        end if;
      end if;
    end loop;
    -- Put_Line("nowy skrot: " & Integer'Image(randomNumber) & " do " & Integer'Image(randomNumber2));

  end loop;

  --display routes
  for I in 0 .. No_of_nodes-1 loop
    Put("Node no. " & Integer'Image(I) & " routes ::::::: ");
    for J in 0 .. No_of_nodes-1 loop
      if nodesAll(I).nextNodes(J)=1 then
        Put(Integer'Image(J) & ", ");
      end if;
    end loop;
    New_Line;
  end loop;

  --sending packets
  for I in 1 .. No_of_packets loop
      --creating and setting packets
      packetsAll(I) := new Packet;
      packetsAll(I).id := I;
      for J in 0 .. No_of_nodes-1 loop
        packetsAll(I).visitedNodes(J) := 0;
      end loop;

      --Printer.print( " wysylam " & Integer'Image(I));
      a1(0).packetInput(packetsAll(I));
  end loop;

  Printer.print( "Czekam na info od ostatniego noda");
  a1(No_of_nodes-1).getEnd(a);
  Printer.print( "Wylaczam symulacje");

  for I in 0 .. No_of_nodes-1 loop
    a1(I).exterminate;
    null;
  end loop;
  Printer.exterminate;
  --Statystyki
  --Nodes Stat
  Put_Line("Informacje wezlow");
  for I in 0 .. No_of_nodes-1 loop
    Put("Node no. " & Integer'Image(I) & "::::::: ");
    for J in 1 .. No_of_packets loop
      if nodesAll(I).handledPackets(J)=1 then
        Put(Integer'Image(J) & ", ");
      end if;
      -- Put(Integer'Image(nodesAll(I).handledPackets(J)) & ", ");
    end loop;
    New_Line;
  end loop;
  --Packet Stat
  Put_Line("Informacje pakietow");
  for I in 1 .. No_of_packets loop
    Put("Packet no. " & Integer'Image(I) & "::::::: ");
    for J in 0 .. No_of_nodes-1 loop
      if packetsAll(I).visitedNodes(J)=1 then
        Put(Integer'Image(J) & ", ");
      end if;
      -- Put(Integer'Image(nodesAll(I).handledPackets(J)) & ", ");
    end loop;
    New_Line;
  end loop;
end main;
