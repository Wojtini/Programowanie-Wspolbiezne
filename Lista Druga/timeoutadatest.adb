with Ada.Text_IO; use ADA.Text_IO;
with Ada.Integer_Text_IO; use Ada.Integer_Text_IO;
with Ada.Command_Line;
with Ada.Strings;
with ada.numerics.discrete_random;
with Ada.Containers; use Ada.Containers;
with Ada.Containers.Vectors;

procedure main is
  task Printer is
    entry getEnd(n: Integer);
  end Printer;
  task body Printer is
  begin
    loop
      accept getEnd(n: Integer) do
        Put_Line("Odebrano");
        delay 10.0;
      end getEnd;
    end loop;
  end Printer;

  task Printer2 is
  end Printer2;
  task body Printer2 is
  begin
    loop

      select
        Printer.getEnd(2);
        Put_Line("Wyslano");
      or
        delay 2.0;
        Put_Line("Too slow");
      end select;

    end loop;
  end Printer2;


  task Printer3 is
  end Printer3;
  task body Printer3 is
  begin
    loop

      select
        Printer.getEnd(3);
        Put_Line("Wyslano");
      or
        delay 2.0;
        Put_Line("Too slow");
      end select;

    end loop;
  end Printer3;
begin
  loop
    null;
  end loop;
end main;
