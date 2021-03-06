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

with AWS.Server;
with AWS.Config;
private with AWS.Services.Dispatchers.Virtual_Host;

package Gwiad.Web is

   procedure Start;
   --  Starts the logger, Gwiad main host and web server

   procedure Start (Configuration : in AWS.Config.Object);
   --  Same as start but using a full configuration objet

   procedure Wait
     (Mode : in AWS.Server.Termination := AWS.Server.Q_Key_Pressed);
   --  Controls the main procedure termination. See AWS.Server.Wait

   procedure Stop;
   --  Stops Gwiad web server

   procedure Reload;
   --  Reloads Gwiad dispatcher

private

   Virtual_Hosts_Dispatcher : AWS.Services.Dispatchers.Virtual_Host.Handler;
   --  The virtual hosts dispatcher control all virtual hosts

end Gwiad.Web;
