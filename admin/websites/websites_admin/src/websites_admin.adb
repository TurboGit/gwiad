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

with Ada.Directories;
with Ada.Text_IO;
with Ada.Exceptions;
with Ada.Strings.Unbounded;

with AWS.Status;
with AWS.Digest;
with AWS.Dispatchers.Callback;
with AWS.Messages;
with AWS.Response;
with AWS.MIME;
with AWS.Services.Dispatchers.URI;
with AWS.Services.ECWF.Registry;
with AWS.Services.ECWF.Context;
with AWS.Templates;
with AWS.Parameters;

with Gwiad.Config.Settings;
with Gwiad.Iniparser;
with Gwiad.Websites.Register;
with Gwiad.Dynamic_Libraries.Manager;
with Gwiad.Web.Register.Virtual_Host;

package body Websites_Admin is

   use Ada;
   use Ada.Strings.Unbounded;

   use Gwiad;

   use AWS;
   use AWS.Templates;

   type Attribute is (Document_Root, Default_Page, Secure, Virtual_Host);
   package Conf is new Gwiad.Iniparser (Attribute);

   Config_Root : constant String := "config";

   Websites_Admin_URL : constant String := "/admin/websites/";

   Main_Dispatcher : AWS.Services.Dispatchers.URI.Handler;

   procedure Discover_Virtual_Host_Directories;
   --  Search wiki website on plugin root path

   function Default_Callback (Request : in Status.Data) return Response.Data;
   --  Registers default callback

   procedure List_Websites
     (Request      : in     Status.Data;
      Context      : access AWS.Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set);
   --  Lists all websites

   procedure Stop_Website
     (Request      : in Status.Data;
      Context      : access AWS.Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set);
   --  Stop a website

   procedure Unload_Websites
     (Request      : in Status.Data;
      Context      : access AWS.Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set);
   --  Unload a library and all associated websites

   ------------------------------
   -- Virtual_Host_Directories --
   ------------------------------

   procedure Virtual_Host_Directories
     (Request      : in Status.Data;
      Context      : access AWS.Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set);
   --  Search for virtual host directories

   ----------------------
   -- Default_Callback --
   ----------------------

   function Default_Callback (Request : in Status.Data) return Response.Data is
      use type Messages.Status_Code;
      use type AWS.Status.Authorization_Type;
      URI          : constant String := Status.URI (Request);
      Translations : Templates.Translate_Set;
      Web_Page     : Response.Data;

      Username    : constant String := AWS.Status.Authorization_Name (Request);
      Client_Mode : constant AWS.Status.Authorization_Type
        := AWS.Status.Authorization_Mode (Request);

   begin

      if Client_Mode = Status.Digest
        and then Username = Config.Settings.Auth_Username
        and then Status.Check_Digest (Request, Config.Settings.Auth_Password)
      then
         if Digest.Check_Nonce
           (Digest.Nonce (AWS.Status.Authorization_Nonce (Request)))
         then
            Web_Page := Services.ECWF.Registry.Build
              (URI, Request, Translations,
               Cache_Control => Messages.Prevent_Cache);

            if Response.Status_Code (Web_Page) = Messages.S404 then
               --  Page not found
               return Response.Build
                 (Content_Type  => MIME.Text_HTML,
                  Message_Body  => "<p>Website admin error</p>");
            else
               return Web_Page;
            end if;
         else
            --  Nonce is stale

            return AWS.Response.Authenticate
              ("Gwiad restricted usage", Response.Digest, Stale => True);
         end if;
      end if;

      --  Unauthorized

      return Response.Authenticate ("Gwiad restricted usage", Response.Digest);

   end Default_Callback;

   ---------------------------------------
   -- Discover_Virtual_Host_Directories --
   ---------------------------------------

   procedure Discover_Virtual_Host_Directories is
      use Ada.Directories;
      S : Search_Type;
      D : Directory_Entry_Type;
   begin
      Start_Search (Search    => S,
                    Directory => Config_Root,
                    Pattern   => "*.ini",
                    Filter    => (Ordinary_File => True, others => False));

      while More_Entries (S) loop
         Get_Next_Entry (S, D);
         declare
            Name : constant String := Simple_Name (D);
         begin
            if Name /= "." and Name /= ".." then
               --  Now read the config file if any

               Conf.IO.Open (Full_Name (D));
               Conf.IO.Close;

               declare
                  use Web.Register.Virtual_Host;
                  Conf_File_Document_Root : constant String :=
                                              Conf.Get_Value (Document_Root);
                  Conf_File_Default_Page  : constant String :=
                                              Conf.Get_Value (Default_Page);
                  VH_Dir : Virtual_Host_Directory :=
                             (Document_Root => To_Unbounded_String
                                (Conf_File_Document_Root),
                              Default_Page  => To_Unbounded_String
                                (Conf_File_Default_Page),
                              Secure        => Conf.Get_Value (Secure));
               begin
                  Register (Hostname => Conf.Get_Value (Virtual_Host),
                            VH_Dir   => VH_Dir);
               end;
            end if;
         exception
            when Conf.IO.Uncomplete_Config =>
               Ada.Text_IO.Put_Line ("uncomplete");
               Conf.IO.Close;
            when UP : Conf.IO.Unknown_Parameter =>
               Text_IO.Put_Line ("Unknown Parameter : "
                                 & Exceptions.Exception_Message (UP));
               Conf.IO.Close;
            when Text_IO.Name_Error =>
               Ada.Text_IO.Put_Line ("Does not exit");
               null;
         end;
      end loop;

   exception
      when E : others =>
         Text_IO.Put_Line (Exceptions.Exception_Information (E));
   end Discover_Virtual_Host_Directories;


   -------------------
   -- List_Websites --
   -------------------

   procedure List_Websites
     (Request      : in     Status.Data;
      Context      : access AWS.Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set)
   is
      pragma Unreferenced (Request, Context);
      use Gwiad.Websites.Register;

      Position     : Cursor := First;

      Names        : Templates.Tag;
      Simple_Paths : Templates.Tag;
      Paths        : Templates.Tag;
      Descriptions : Templates.Tag;

   begin
      while Has_Element (Position) loop
         Names        := Names & Name (Position);
         Paths        := Paths & Path (Position);
         Simple_Paths := Simple_Paths
           & Directories.Simple_Name (Path (Position));
         Descriptions := Descriptions & Description (Position);
         Next (Position);
      end loop;

      Templates.Insert (Translations, Templates.Assoc ("NAME", Names));

      Templates.Insert (Translations, Templates.Assoc ("PATH", Paths));

      Templates.Insert (Translations,
                        Templates.Assoc ("DESCRIPTION", Descriptions));

      Templates.Insert
        (Translations, Templates.Assoc ("SIMPLE_PATH", Simple_Paths));

      Templates.Insert
        (Translations,
         Templates.Assoc ("WEBSITES_ADMIN_URL", Websites_Admin_URL));
   end List_Websites;

   ------------------
   -- Stop_Website --
   ------------------

   procedure Stop_Website
     (Request      : in Status.Data;
      Context      : access AWS.Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set)
   is
      pragma Unreferenced (Context, Translations);
      use Gwiad.Websites.Register;

      P            : constant Parameters.List := Status.Parameters (Request);
      Service_Name : constant String          := Parameters.Get (P, "service");

      Library_Path : Unbounded_String := Null_Unbounded_String;

   begin

      declare
         Position : constant Cursor := Find (Service_Name);
      begin
         if Has_Element (Position) then
            Library_Path := To_Unbounded_String (Path (Position));
         end if;
      end;

      if Library_Path /= "" then
         Unregister (Service_Name);
      end if;
   end Stop_Website;

   --------------------
   -- Unload_Website --
   --------------------

   procedure Unload_Websites
     (Request      : in Status.Data;
      Context      : access AWS.Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set)
   is
      pragma Unreferenced (Context);
      use Gwiad.Websites.Register;
      use Dynamic_Libraries.Manager;

      P            : Parameters.List  := Status.Parameters (Request);
      Library_Path : constant String  := Parameters.Get (P, "lib");
      Dry_Run      : constant String  := Parameters.Get (P, "dry_run");

      Tag_Name : Templates.Tag;
   begin

      declare
         Position : Cursor := First;
      begin
         while Has_Element (Position) loop
            if Path (Position) /= Library_Path then
               Next (Position);
            else
               if Dry_Run /= "" then
                  Tag_Name := Tag_Name & Name (Position);
                  Next (Position);
               else
                  declare
                     Last_Position : constant Cursor := Position;
                  begin
                     Next (Position);
                     Unregister (Name (Last_Position));
                  end;
               end if;
            end if;
         end loop;
      end;

      Templates.Insert (Translations, Templates.Assoc ("PATH", Library_Path));

      Templates.Insert
        (Translations,
         Templates.Assoc
           ("SIMPLE_PATH", Directories.Simple_Name (Library_Path)));

      Templates.Insert
        (Translations,
         Templates.Assoc ("WEBSITES_ADMIN_URL", Websites_Admin_URL));


      if Dry_Run /= "" then
         Templates.Insert (Translations, Templates.Assoc ("DRY_RUN", "yes"));
         Templates.Insert (Translations, Templates.Assoc ("NAME", Tag_Name));
      else
         Manager.Unload (Library_Path);
      end if;

   end Unload_Websites;

   ------------------------------
   -- Virtual_Host_Directories --
   ------------------------------

   procedure Virtual_Host_Directories
     (Request      : in Status.Data;
      Context      : access AWS.Services.ECWF.Context.Object;
      Translations : in out Templates.Translate_Set)
   is
   begin
      Discover_Virtual_Host_Directories;
      List_Websites (Request, Context, Translations);
   end Virtual_Host_Directories;

begin

   AWS.Services.Dispatchers.URI.Register_Default_Callback
     (Main_Dispatcher,
      Dispatchers.Callback.Create (Default_Callback'Access));
   --  This default callback will handle all ECWF callbacks

   --  Register ECWF pages

   AWS.Services.ECWF.Registry.Register
     (Websites_Admin_URL & "list",
      "templates/websites_admin/list.thtml",
      List_Websites'Access,
      MIME.Text_HTML);

   AWS.Services.ECWF.Registry.Register
     (Websites_Admin_URL & "stop",
      "templates/websites_admin/stop.thtml",
      Stop_Website'Access,
      MIME.Text_HTML);

   AWS.Services.ECWF.Registry.Register
     (Websites_Admin_URL & "unload",
      "templates/websites_admin/unload.thtml",
      Unload_Websites'Access,
      MIME.Text_HTML);

   AWS.Services.ECWF.Registry.Register
     (Websites_Admin_URL & "find_vhd",
      "templates/websites_admin/list.thtml",
      Virtual_Host_Directories'Access,
      MIME.Text_HTML);

   Gwiad.Web.Register.Register (Web_Dir  => Websites_Admin_URL,
                                Action   => Main_Dispatcher);

end Websites_Admin;
