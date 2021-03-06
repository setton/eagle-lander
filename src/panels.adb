-------------------------------------------------------------------------------
--                                                                           --
--                               Eagle Lander                                --
--                                                                           --
--         Copyright (C) 2015 Fabien Chouteau (chouteau@adacore.com)         --
--                                                                           --
--    Eagle Lander is free software: you can redistribute it and/or modify   --
--    it under the terms of the GNU General Public License as published by   --
--    the Free Software Foundation, either version 3 of the License, or      --
--    (at your option) any later version.                                    --
--                                                                           --
--    Foobar is distributed in the hope that it will be useful,              --
--    but WITHOUT ANY WARRANTY; without even the implied warranty of         --
--    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the          --
--    GNU General Public License for more details.                           --
--                                                                           --
--    You should have received a copy of the GNU General Public License      --
--    along with Eagle Lander.  If not, see <http://www.gnu.org/licenses/>.  --
--                                                                           --
-------------------------------------------------------------------------------

with Interfaces.C.Strings; use Interfaces.C.Strings;
with Cairo.Image_Surface; use Cairo.Image_Surface;
with Ada.Text_IO; use Ada.Text_IO;
with Lander; use Lander;
with Ada.Numerics;
with Ada.Numerics.Float_Random; use Ada.Numerics.Float_Random;
with Pango.Layout; use Pango.Layout;
with Pango.Font; use Pango.Font;
with Pango.Cairo; use Pango.Cairo;
with Pango.Context; use Pango.Context;
with System; use System;
with Glib.Object;
with Pango; use Pango;
with Pango.Enums; use Pango.Enums;


package body Panels is

   G : Ada.Numerics.Float_Random.Generator;

   function In_Panel (P : Panel; Evt : Vector2D) return Boolean is
   begin
      return Evt.X >= P.Pos.X and then P.Pos.X + P.Size.X * P.Scale >= Evt.X
        and then
          Evt.Y >= P.Pos.Y and then P.Pos.Y + P.Size.Y * P.Scale >= Evt.Y;
   end In_Panel;

   function On_Click (P : in out Panel; Evt : Vector2D) return Boolean is
   begin
      if In_Panel (P, Evt) and then not P.Resized then
         P.Clicked := True;
         P.Click_Pos := Evt;
         return True;
      end if;
      return False;
   end On_Click;

   function On_Resize (P : in out Panel; Evt : Vector2D) return Boolean is
   begin
      if In_Panel (P, Evt) and then not P.Clicked then
         P.Resized := True;
         P.Click_Pos := Evt;
         return True;
      end if;
      return False;
   end On_Resize;

   procedure On_Released (P : in out Panel; Evt : Vector2D) is
   begin
      P.Clicked := False;
      P.Resized := False;
   end On_Released;

   procedure On_Motion (P : in out Panel; Evt : Vector2D) is
      Mvt : Vector2D;
--        Ratio : Gdouble;
      Ratio : Vector2D;
   begin
      if P.Clicked or else P.Resized then
         Mvt := Evt - P.Click_Pos;
         if P.Clicked then
            P.Pos := P.Pos + Mvt;
         else
            Ratio.X := Mvt.X / P.Size.X;
            Ratio.Y := Mvt.Y / P.Size.Y;
            --              Ratio := ((Mvt.X ** 2 + Mvt.Y ** 2) ** (-2)) / 20.0;
            if Ratio.X > Ratio.Y then
               Ratio.Y := Ratio.X;
            else
               Ratio.X := Ratio.Y;
            end if;

            P.Scale := P.Scale + Ratio.X;
            if P.Scale < 0.2 then
               P.Scale := 0.2;
            end if;
         end if;
         P.Click_Pos := Evt;
      end if;
   end On_Motion;

   procedure Draw_Frame (Self : in out Panel; Cr : Cairo_Context) is
      Line_Widht  : constant Gdouble := 4.0;
      Line_Margin : constant Gdouble := Line_Widht * 1.2;
      Real_Size   : constant Vector2D := Self.Size * Self.Scale;

      procedure Draw_Screw (Angle : Gdouble; Pos : Vector2D) is
      begin
         Save (Cr);
         Translate (Cr, Pos.X, Pos.Y);
         Set_Source_Rgb (Cr, 0.25, 0.25, 0.25);
         Arc (Cr, 0.0, 0.0, 1.4 * Line_Widht, 0.0, 2.0 * Ada.Numerics.Pi);
         Fill (Cr);

         Set_Source_Rgb (Cr, 0.2, 0.2, 0.2);
         Arc (Cr, 0.0, 0.0, 1.1 * Line_Widht, 0.0, 2.0 * Ada.Numerics.Pi);
         Fill_Preserve (Cr);

         Clip (Cr);
         Rotate (Cr, Angle);
         Move_To (Cr, -4.0 * Line_Widht, -4.0 * Line_Widht);
         Line_To (Cr, 4.0 * Line_Widht, 4.0 * Line_Widht);
         Set_Source_Rgb (Cr, 0.5, 0.5, 0.5);
         Set_Line_Width (Cr, 0.6 * Line_Widht);
         Stroke (Cr);
         Restore (Cr);
      end Draw_Screw;
   begin
      Self.Inner_Frame_Pos := Self.Pos +
        (2.0 * Line_Margin, 2.0 * Line_Margin);

      Self.Inner_Frame_Size := Self.Size -
        (4.0 * Line_Margin, 4.0 * Line_Margin) / Self.Scale;

      if not Self.Frame_Initialized then
         for Screw of Self.Screws_Angle loop
            Screw := Gdouble (Random (G) * Ada.Numerics.Pi);
         end loop;
         Self.Frame_Initialized := True;
      end if;

      Save (Cr);
      Translate (Cr, Self.Pos.X, Self.Pos.Y);

      -- Draw a rectagle wiht round edges

      Set_Background_Color (Cr);
      Rectangle (Cr, Line_Widht / 2.0, Line_Widht / 2.0,
                 Real_Size.X - Line_Widht,
                 Real_Size.Y - Line_Widht);
      Set_Line_Join (Cr, Cairo_Line_Join_Round);
      Set_Line_Width (Cr, Line_Widht);
      Stroke (Cr);
      Rectangle (Cr, Line_Widht, Line_Widht,
                 Real_Size.X - 2.0 * Line_Widht,
                 Real_Size.Y - 2.0 * Line_Widht);
      Fill (Cr);

      --  Draw white contour line

      Rectangle (Cr, Line_Margin, Line_Margin,
                 Real_Size.X - 2.0 * Line_Margin,
                 Real_Size.Y - 2.0 * Line_Margin);
      Set_Source_Rgb (Cr, 1.0, 1.0, 1.0);
      Stroke (Cr);

      --  Draw scews
      Draw_Screw (Self.Screws_Angle (1), (Line_Widht * 1.5, Line_Widht * 1.5));
      Draw_Screw (Self.Screws_Angle (2),
                  (Real_Size.X - Line_Widht * 1.5,
                  Real_Size.Y - Line_Widht * 1.5));
      Draw_Screw (Self.Screws_Angle (1), (Line_Widht * 1.5,  Real_Size.Y - Line_Widht * 1.5));
      Draw_Screw (Self.Screws_Angle (2), (Real_Size.X - Line_Widht * 1.5, Line_Widht * 1.5));
      Restore (Cr);
   end Draw_Frame;

   procedure Set_Background_Color (Cr : Cairo_Context) is
      Grey : constant Gdouble := 0.35;

   begin
      Set_Source_Rgb (Cr, Grey, Grey, Grey);
   end Set_Background_Color;

   function Create_Layout (Context : Cairo_Context)
                           return Pango_Layout is
      function Internal (Context : Cairo_Context) return Address;
      pragma Import (C, Internal, "pango_cairo_create_layout");
      Stub : Pango_Layout_Record;
   begin
--        return Pango_Layout (Get_User_Data (Internal (Context), Stub));
      return Pango_Layout
        (Glib.Object.Get_User_Data (Internal (Context), Stub));
   end Create_Layout;

   function LM_Font (Cr : Cairo_Context; Size : Gdouble;
                     Gravity : Pango.Enums.Gravity :=
                       Pango.Enums.Pango_Gravity_South) return Pango_Layout is
      Layout : Pango_Layout;
      Desc   : Pango_Font_Description;
   begin
      Layout := Create_Layout (Cr);
      Desc := Pango.Font.From_String ("arial bold 9");
      --        Set_Weight (Desc, Pango_Weight_Bold);
      Set_Size (Desc, Gint (Size) * 750);
      Set_Gravity (Desc, Gravity);
      Set_Font_Description (Layout, Desc);
      return Layout;
   end LM_Font;

   procedure Draw_Centered_Text (Cr : Cairo_Context;
                                 Text : String;
                                 Pos : Vector2D;
                                 Size : Gdouble;
                                 Gravity : Pango.Enums.Gravity :=
                                   Pango.Enums.Pango_Gravity_South) is
         Layout : Pango_Layout;
         Ink_Rect    : Pango_Rectangle;
         Logical_Rect : Pango_Rectangle;
   begin
      Layout := LM_Font (Cr, Size, Gravity);
      Set_Text (Layout, Text);
      Layout.Get_Pixel_Extents (Ink_Rect, Logical_Rect);
      Save (Cr);
      Move_To (Cr, Pos.X - Gdouble (Logical_Rect.Width / 2),
               Pos.Y - Gdouble (Logical_Rect.Height / 2));
      Pango.Cairo.Show_Layout  (Cr, Layout);
      Restore (Cr);
   end Draw_Centered_Text;

   procedure Draw_Right_Text (Cr : Cairo_Context;
                              Text : String;
                              Pos : Vector2D;
                              Size : Gdouble) is
         Layout : Pango_Layout;
         Ink_Rect    : Pango_Rectangle;
         Logical_Rect : Pango_Rectangle;
   begin
      Layout := LM_Font (Cr, Size);
      Set_Text (Layout, Text);
      Layout.Get_Pixel_Extents (Ink_Rect, Logical_Rect);
      Save (Cr);
      Move_To (Cr, Pos.X - Gdouble (Logical_Rect.Width),
               Pos.Y - Gdouble (Logical_Rect.Height / 2));
      Pango.Cairo.Show_Layout  (Cr, Layout);
      Restore (Cr);
   end Draw_Right_Text;

   procedure Init (Self : in out Gauge;
                   Text : String;
                   Pos  : Vector2D;
                   Size : Vector2D)
   is
   begin
      Self.Size := Size;
      Self.Pos  := Pos;
      Self.Text := new String'(Text);
   end Init;

   procedure Draw (Self  : in out Gauge;
                   Cr    : Cairo_Context;
                   Value : Gdouble)
   is
      Size        : constant Vector2D := Self.Inner_Frame_Size;
      Margin_Side : constant Gdouble := 0.06 * Size.X;
      Margin_Up   : constant Gdouble := 0.15 * Size.Y;
      Bar_Width   : constant Gdouble := 0.15 * Size.X;
      Bar_Height  : constant Gdouble := Size.Y - Margin_Up - Margin_Side;
      H : constant Gdouble := Margin_Up + (1.0 - Value) * Bar_Height * 0.9;
   begin
      Self.Draw_Frame (Cr);
      Save (Cr);
      Translate (Cr, Self.Inner_Frame_Pos.X, Self.Inner_Frame_Pos.Y);
      Scale (Cr, Self.Scale, Self.Scale);


      -- static Background

      --  Black Background
      Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
      Rectangle (Cr,
                 Margin_Side * 0.5,
                 Margin_Up * 0.9,
                 Size.X - Margin_Side * 1.0,
                 Size.Y - Margin_Up * 0.8 - Margin_Side);
      Fill (Cr);

      Set_Source_Rgb (Cr, 1.0, 1.0, 1.0);

      Draw_Centered_Text (Cr, Self.Text.all,
                          (X => Size.X / 2.0, Y => Margin_Up / 2.0),
                          Margin_Up * 0.8);
      --  Two Side Lines
      Rectangle (Cr, Margin_Side, Margin_Up,
                 Bar_Width, Bar_Height);
      Fill (Cr);
      Rectangle (Cr, Size.X - Margin_Side, Margin_Up,
                 -Bar_Width, Bar_Height);
      Fill (Cr);

      declare
         Tick_Spacing : constant Gdouble := Bar_Height * 0.9 / 20.0;
         Tick_Y : Gdouble := Margin_Up + Bar_Height * 0.05;
         Tick_Width : Gdouble;
         Tick_X_L  : constant Gdouble := Margin_Side + Bar_Width;
         Tick_X_R  : constant Gdouble := Size.X - Margin_Side - Bar_Width;
      begin
         for Cnt in 1 .. 21 loop
            Tick_Width :=
              (if Cnt mod 2 = 1 then Bar_Width else Bar_Width / 2.0);

            Move_To (Cr, Tick_X_L, Tick_Y);
            Line_To (Cr, Tick_X_L + Tick_Width, Tick_Y);
            Move_To (Cr, Tick_X_R, Tick_Y);
            Line_To (Cr, Tick_X_R - Tick_Width, Tick_Y);
            Stroke (Cr);

            Tick_Y := Tick_Y + Tick_Spacing;
         end loop;
      end;
      declare
         Tick_Spacing : constant Gdouble := Bar_Height * 0.9 / 20.0;
         Tick_Y : Gdouble := Margin_Up + Bar_Height * 0.05;
      begin
         for Cnt in reverse 0 .. 5 loop
            Draw_Centered_Text (Cr, Integer'Image (Cnt * 20),
                                (X => Size.X / 2.0, Y => Tick_Y),
                                Tick_Spacing * 1.5);
            Tick_Y := Tick_Y + Tick_Spacing * 4.0;
         end loop;
      end;
      --  End of static background

      --  Draw Cursors
      Set_Source_Rgb (Cr, 0.1, 0.1, 0.1);
      Move_To (Cr, Margin_Side - 1.0, H);
      Line_To (Cr, Margin_Side + Bar_Width, H + Bar_Height * 0.05);
      Line_To (Cr, Margin_Side - 1.0, H + Bar_Height * 0.1);
      Close_Path (Cr);
      Fill (Cr);
      Move_To (Cr, Size.X - Margin_Side + 1.0, H);
      Line_To (Cr, Size.X - Margin_Side - Bar_Width,
               H + Bar_Height * 0.05);
      Line_To (Cr, Size.X - Margin_Side + 1.0, H + Bar_Height * 0.1);
      Close_Path (Cr);
      Fill (Cr);
      Restore (Cr);
   end Draw;

   procedure Init (Self : in out Xpointer;
                   Pos  : Vector2D;
                   Size : Gdouble)
   is
   begin
      Self.Pos := Pos;
      Self.Size := (Size, Size);
   end Init;

   procedure Draw (Self  : in out Xpointer;
                   Cr    : Cairo_Context;
                   Value : Speed_Vect)
   is

      Size         : constant Gdouble := Self.Inner_Frame_Size.X;
      Margin_Large : constant Gdouble := Size * 0.2;
      Margin_Small : constant Gdouble := Size * 0.1;
      Screen_Size  : constant Gdouble := 0.70 * Size;
      Tick_Spacing : constant Gdouble := Screen_Size * 0.9 / 16.0;

      Target   : Vector2D  := (Gdouble (Value.X), Gdouble (Value.Y));
      X_Factor : Integer := 1;
      Y_Factor : Integer := 1;
      Safe     : Vector2D;
   begin
      Self.Draw_Frame (Cr);
      while abs Target.X > 20.0 loop
         X_Factor := X_Factor * 10;
         Target.X := Target.X / 10.0;
      end loop;
      while abs Target.Y > 20.0 loop
         Y_Factor := Y_Factor * 10;
         Target.Y := Target.Y / 10.0;
      end loop;

      Target := Target * (Tick_Spacing / 2.5);
      Target.Y := -Target.Y;

      Save (Cr);
      Translate (Cr, Self.Inner_Frame_Pos.X, Self.Inner_Frame_Pos.Y);
      Scale (Cr, Self.Scale, Self.Scale);

      --  Static background

      --  Black Background
      Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
      Rectangle (Cr, Margin_Small * 0.8, Margin_Small * 0.8,
                 Screen_Size * 1.2, Screen_Size * 1.2);
      Fill (Cr);

      Set_Source_Rgb (Cr, 1.0, 1.0, 1.0);
      --  Screen
      Rectangle (Cr, Margin_Large, Margin_Small,
                 Screen_Size, Screen_Size);
      Fill (Cr);

      Set_Line_Width (Cr, 1.0);
      declare
         Tick_Spacing : constant Gdouble := Screen_Size * 0.9 / 16.0;
         Tick1_Y : Gdouble := Margin_Small + Screen_Size * 0.05;
         Tick1_X : constant Gdouble := Margin_Large;
         Tick2_Y : constant Gdouble := Margin_Small + Screen_Size;
         Tick2_X : Gdouble := Margin_Large + Screen_Size * 0.05;
         Tick_Width : Gdouble;
      begin
         for Cnt in 1 .. 17 loop
            Tick_Width :=
              (if Cnt mod 2 = 1 then Margin_Small / 2.0
               else Margin_Small / 4.0);

            Move_To (Cr, Tick1_X, Tick1_Y);
            Line_To (Cr, Tick1_X - Tick_Width, Tick1_Y);
            Stroke (Cr);

            Move_To (Cr, Tick2_X, Tick2_Y);
            Line_To (Cr, Tick2_X, Tick2_Y + Tick_Width);
            Stroke (Cr);

            Tick1_Y := Tick1_Y + Tick_Spacing;
            Tick2_X := Tick2_X + Tick_Spacing;
         end loop;
      end;

      declare
         Tick_Spacing : constant Gdouble := Screen_Size * 0.9 / 8.0;
         Tick1_Y : Gdouble := Margin_Small + Screen_Size * 0.05;
         Tick2_X : Gdouble := Margin_Large + Screen_Size * 0.05;
      begin
         for Cnt in 0 .. 8 loop
            Draw_Centered_Text (Cr, Integer'Image (abs (20 - Cnt * 5)),
                                (X => Margin_Large - Margin_Small,
                                 Y => Tick1_Y),
                                Tick_Spacing / 2.0);
            Draw_Centered_Text (Cr, Integer'Image (abs (20 - Cnt * 5)),
                                (X => Tick2_X,
                                 Y => 2.0 * Margin_Small + Screen_Size),
                                Tick_Spacing / 2.0);
            Tick1_Y := Tick1_Y + Tick_Spacing;
            Tick2_X := Tick2_X + Tick_Spacing;
         end loop;
      end;
      Set_Source_Rgb (Cr, 0.8, 0.8, 0.8);
      Move_To (Cr, Margin_Large + Screen_Size / 2.0, Margin_Small);
      Line_To (Cr, Margin_Large + Screen_Size / 2.0,
               Margin_Small + Screen_Size);
      Stroke (Cr);

      Set_Source_Rgb (Cr, 0.8, 0.8, 0.8);
      Move_To (Cr, Margin_Large, Margin_Small + Screen_Size / 2.0);
      Line_To (Cr, Margin_Large + Screen_Size,
               Margin_Small + Screen_Size / 2.0);
      Stroke (Cr);
      --  End of Static background

--        Set_Source_Surface (Cr, Self.Static, 0.0, 0.0);
--        Paint (Cr);

      --  Draw Factors
      Set_Source_Rgb (Cr, 0.0, 1.0, 0.0);
      Draw_Centered_Text (Cr, "x" & Y_Factor'Img & " m/s",
                          (X => Margin_Large - Margin_Small,
                           Y => Margin_Small / 2.0),
                          Tick_Spacing);
      Draw_Centered_Text (Cr, "x" & X_Factor'Img & " m/s",
                          (X => Size - Margin_Small,
                           Y => 2.5 * Margin_Small + Screen_Size),
                          Tick_Spacing);

      --  Screen Mask
      Rectangle (Cr, Margin_Large, Margin_Small, Screen_Size, Screen_Size);
      Clip (Cr);

      Target := Target + Screen_Size / 2.0;
      Set_Source_Rgb (Cr, 0.0, 0.0, 0.0);
      Move_To (Cr, Margin_Large + Target.X, Margin_Small);
      Line_To (Cr, Margin_Large + Target.X, Margin_Small + Screen_Size);
      Stroke (Cr);

      Move_To (Cr, Margin_Large, Margin_Small + Target.Y);
      Line_To (Cr, Margin_Large + Screen_Size, Margin_Small + Target.Y);
      Stroke (Cr);


      --  Draw safe landing margins
      Set_Source_Rgba (Cr, 1.0, 0.0, 0.0, 0.35);
      if Y_Factor = 1 then
         Safe.Y := Screen_Size / 2.0 +
           Gdouble (Safe_Landing_Vel.Y) * (Tick_Spacing / 2.5);
         Move_To (Cr, Margin_Large, Margin_Small + Safe.Y);
         Line_To (Cr, Margin_Large + Screen_Size, Margin_Small + Safe.Y);
         Stroke (Cr);
      end if;
      if X_Factor = 1 then
         Safe.X := Screen_Size / 2.0 +
           Gdouble (Safe_Landing_Vel.X) * (Tick_Spacing / 2.5);
         Move_To (Cr, Margin_Large + Safe.X, Margin_Small);
         Line_To (Cr, Margin_Large + Safe.X, Margin_Small + Screen_Size);
         Stroke (Cr);
         Safe.X := Screen_Size / 2.0 -
           Gdouble (Safe_Landing_Vel.X) * (Tick_Spacing / 2.5);
         Move_To (Cr, Margin_Large + Safe.X, Margin_Small);
         Line_To (Cr, Margin_Large + Safe.X, Margin_Small + Screen_Size);
         Stroke (Cr);
      end if;
      Restore (Cr);
   end Draw;
begin
   Reset (G, 1987);
end Panels;
