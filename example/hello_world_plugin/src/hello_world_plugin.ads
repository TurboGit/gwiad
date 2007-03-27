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

with Gwiad.Plugins;
with Hello_World_Interface;

package Hello_World_Plugin is

   use Gwiad.Plugins;
   use Hello_World_Interface;

   type Hello_World_Plugin is new HW_Plugin with null record;

   type Hello_World_Plugin_Access is access all Hello_World_Plugin;

   function Hello (P : Hello_World_Plugin) return String;
   --  Hello world

private

   function Builder return access Plugin'Class;
   --  Build a new test plugin

end Hello_World_Plugin;
