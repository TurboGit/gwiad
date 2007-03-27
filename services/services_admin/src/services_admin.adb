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

with Gwiad.Plugins.Register;
with Gwiad.Dynamic_Libraries.Manager;
with Gwiad.Web;

with AWS.Dispatchers.Callback;
with AWS.Messages;
with AWS.MIME;
with AWS.Services.ECWF.Registry;
with AWS.Services.ECWF.Context;
with AWS.Templates;
with AWS.Parameters;
with Ada.Strings.Unbounded;

package body Services_Admin is

   use Gwiad;
   use Gwiad.Plugins;

   use AWS.Templates;

   procedure List_Services
     (Request      : in     Status.Data;
      Context      : access Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set);
   --  Lists all services

   procedure Stop_Service
     (Request      : in Status.Data;
      Context      : access Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set);
   --  Stop a gwiad service

   ----------------------
   -- Default_Callback --
   ----------------------

   function Default_Callback (Request : in Status.Data) return Response.Data is
      use type Messages.Status_Code;
      URI          : constant String := Status.URI (Request);
      Translations : Templates.Translate_Set;
      Web_Page     : Response.Data;
   begin

      Web_Page := Services.ECWF.Registry.Build
        (URI, Request, Translations, Cache_Control => Messages.Prevent_Cache);

      if Response.Status_Code (Web_Page) = Messages.S404 then
         --  Page not found
         return Services.ECWF.Registry.Build
           ("/404", Request, Translations);

      else
         return Web_Page;
      end if;
   end Default_Callback;

   -------------------
   -- List_Services --
   -------------------

   procedure List_Services
     (Request      : in     Status.Data;
      Context      : access Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set)
   is
      pragma Unreferenced (Request, Context);
      use Gwiad.Plugins.Register;

      Position : Cursor := First;

      Tag_Name : Templates.Tag;
      Tag_Description : Templates.Tag;

   begin
      while Has_Element (Position) loop
         Tag_Name        := Tag_Name & Name (Position);
         Tag_Description := Tag_Description & Description (Position);
         Next (Position);
      end loop;

      Templates.Insert (Translations, Templates.Assoc ("NAME", Tag_Name));
      Templates.Insert (Translations,
                        Templates.Assoc ("DESCRIPTION", Tag_Description));
   end List_Services;

   ------------------
   -- Stop_Service --
   ------------------

   procedure Stop_Service
     (Request      : in Status.Data;
      Context      : access Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set)
   is
   pragma Unreferenced (Context, Translations);
      use Gwiad.Plugins.Register;
      use Dynamic_Libraries.Manager;
      use Ada.Strings.Unbounded;

      P            : Parameters.List  := Status.Parameters (Request);
      Service_Name : constant String  := Parameters.Get (P, "service");
      Library_Path : Unbounded_String := Null_Unbounded_String;

   begin

      declare
         Position     : constant Cursor := Find (Service_Name);
      begin
         if Has_Element (Position) then
            Library_Path := To_Unbounded_String (Path (Position));
         end if;
      end;

      if Library_Path /= "" then
         Unregister (Service_Name);
         Manager.Unload (To_String (Library_Path));
      end if;
   end Stop_Service;

begin

   Services.Dispatchers.URI.Register_Default_Callback
     (Main_Dispatcher,
      Dispatchers.Callback.Create (Default_Callback'Access));
   --  This default callback will handle all ECWF callbacks

   --  Register ECWF pages

   Services.ECWF.Registry.Register
     ("/list",
      "templates/services_admin/list.thtml",
      List_Services'Access,
      MIME.Text_HTML);

   Services.ECWF.Registry.Register
     ("/stop",
      "templates/services_admin/stop.thtml",
      Stop_Service'Access,
      MIME.Text_HTML);

   Gwiad.Web.Register (Hostname => "localhost",
                       Action   => Main_Dispatcher);

end Services_Admin;
