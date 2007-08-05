------------------------------------------------------------------------------
--                                  Gwiad                                   --
--                                                                          --
--                           Copyright (C) 2007                             --
--                            Olivier Ramonat                               --
--                                                                          --
--  This library is free software; you can redistribute it and/or modify    --
--  it under the terms of the GNU General Public License as published by    --
--  the Free Software Foundation; either version 2 of the License, or (at   --
--  your option) any later version.                                         --
--                                                                          --
--  This library is distributed in the hope that it will be useful, but     --
--  WITHOUT ANY WARRANTY; without even the implied warranty of              --
--  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU       --
--  General Public License for more details.                                --
--                                                                          --
--  You should have received a copy of the GNU General Public License       --
--  along with this library; if not, write to the Free Software Foundation, --
--  Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.       --
------------------------------------------------------------------------------

with Ada.Strings.Unbounded;
--  with Ada.Unchecked_Deallocation;

package Gwiad.Plugins is

   use Ada.Strings.Unbounded;

   type Plugin is tagged record
      Description   : Unbounded_String;
      Path          : Unbounded_String;
   end record;

   type Unload_CB is private;

   type Unload_CB_Access is access all Unload_CB;

   function New_Unload_CB (Path : in String) return Unload_CB_Access;

   procedure Call (Unload_CB : in out Unload_CB_Access);
   --  Call unload callbacks

   --------------
   -- Register --
   --------------

   procedure Register
     (Path : in String; Unload_CB : in Gwiad.Plugins.Unload_CB_Access);
   --  Registers a new website
   --  This must be called before registering the service to set the library
   --  path before the service registration
   --  The unload callback procedure is called by dynamic plugin manager on
   --  library unload

   procedure Set_Unload_CB (Callback : access procedure);
   --  Set plugin library unload CB (must be called by the plugin library)

   function Get_Last_Library_Path return String;
   --  Returns last library path

private

   function Get_Last_Unload_CB return Unload_CB_Access;
   --  Returns the current library path
   --  This me be called on library init

   type Unload_CB is record
      Path              : String_Access;
      Callback          : access procedure;
      Internal_Callback : access procedure (Path : in String);
   end record;

   procedure Set_Internal_Unload_CB
     (Callback : access procedure (Path : in String));
   --  Set internal unload callback

end Gwiad.Plugins;
