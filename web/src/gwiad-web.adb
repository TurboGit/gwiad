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

with AWS.Server.Log;
with AWS.Config.Set;

with Gwiad.Web.Main_Host;

package body Gwiad.Web is

   use AWS;

   HTTP          : Server.HTTP;

   task Reload_Dispatcher is

      entry Stop;
      --  Exit reload dispatcher

   end Reload_Dispatcher;

   ------------
   -- Reload --
   ------------

   protected body Reload is

      ------------
      --  Done  --
      ------------

      procedure Done is
      begin
         Reload_Required := False;
      end Done;

      ---------------
      -- Do_Reload --
      ---------------

      function Is_Required return Boolean is
      begin
         return Reload_Required;
      end Is_Required;

      --------------
      -- Required --
      --------------

      procedure Require is
      begin
         Reload_Required := True;
      end Require;

   end Reload;

   -----------------------
   -- Reload_Dispatcher --
   -----------------------

   task body Reload_Dispatcher is
   begin
      loop
         select
            accept Stop;
            exit;
         else
            delay 1.0;
            if Reload.Is_Required then
               Server.Set (Web_Server => HTTP,
                           Dispatcher => Virtual_Hosts_Dispatcher);
               Reload.Done;
            end if;
         end select;
      end loop;
   end Reload_Dispatcher;

   -----------
   -- Start --
   -----------

   procedure Start is
      Configuration : Config.Object;
   begin
      --  Log control

      Server.Log.Start (Web_Server => HTTP, Auto_Flush => True);
      Server.Log.Start_Error (Web_Server => HTTP);

      --  Main host start

      Gwiad.Web.Main_Host.Start;

      --  Server configuration

      Configuration := Config.Get_Current;

      Config.Set.Session (O => Configuration, Value => True);
      Config.Set.Upload_Directory (Configuration, Upload_Directory);
      Config.Set.Admin_URI (Configuration, Admin_URI);

      Server.Start (HTTP, Virtual_Hosts_Dispatcher, Configuration);
   end Start;

   ----------
   -- Stop --
   ----------

   procedure Stop is
   begin
      Server.Shutdown (HTTP);
      Reload_Dispatcher.Stop;
   end Stop;

   ----------
   -- Wait --
   ----------

   procedure Wait (Mode : in Server.Termination := Server.Q_Key_Pressed) is
   begin
      Server.Wait (Mode => Mode);
   end Wait;

end Gwiad.Web;
