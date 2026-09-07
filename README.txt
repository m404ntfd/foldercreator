SHIRT DESIGN FOLDER BUILDER
===========================

Program version: 2.1.0

WINDOW RESIZING AND WINDOWS SNAP
- The program can be freely resized like a standard Windows application.
- Drag the title bar to the left or right edge to snap it to half the screen.
- You can also press Windows key + Left Arrow or Windows key + Right Arrow.
- Narrow windows automatically rearrange the Create and Settings screens so
  controls remain usable. Scroll bars appear when the available height is small.

HOW TO INSTALL
1. Download ShirtFolderSetup.exe from the latest GitHub release.
2. Double-click the installer and approve the Windows administrator prompt.
3. Keep "Create a desktop shortcut" selected.
4. Complete setup and launch the program from the desktop or Start menu.

The installed application appears in Windows Settings > Apps > Installed apps
and can be uninstalled normally. The included .bat file is only for developers
who want to run the source version without installing it.

FIRST-TIME SETUP
1. Open the Settings menu > Categories & Subcategories, or click the Manage
   Categories button on the main screen.
2. Rename the starter "General" category or add your own categories.
3. Select each category and add its subcategories.
4. Open Settings > Preset Location and choose the main directory where design
   folders should normally be created.

CREATING A DESIGN
1. Select a category and subcategory.
2. Enter the design name.
3. Click "Create in Preset Location", or click "Choose Location & Create" for
   a one-time alternate destination.

NUMBERING
- AA is the category ID.
- BB is the subcategory ID within that category.
- CC is the next design number for that category/subcategory.
- IDs use at least two digits: 01 through 99, then 100, 101, and so on.
- Category and subcategory IDs do not change when an item is renamed.
- The program checks both its history and the destination directory before
  selecting the next CC number.

FOLDER TEMPLATE
Settings > Folder Template contains two editable lists:
- Size File Set: one size folder per line.
- Folder Template: one relative folder path per line.

Use the exact marker {SIZE FILE SET} in a template path. The program replaces
that marker with every line in the Size File Set list. This lets the same size
folders be created under Final Print Files, Final Print Canva Files, and Final
TIFFs.

"Original PNG or JPG" is a main folder at the same level as Colors Offered,
Final Print Files, Final Print Canva Files, Final TIFFs, and Online Images.

CREATED DESIGNS
The Created Designs tab records folders made by the program. From there you can:
- Open a design folder in File Explorer.
- Rename a design while keeping its assigned code.
- Create any folders missing from the current template.
- Remove an entry from program history without deleting actual files.
- Clear all displayed history and leftover app update-cache files. This cleanup
  never deletes actual design folders, design files, categories, or templates.

RETURNING FROM SETTINGS
Click "Return to Create Screen" in the blue bar at the bottom of Settings.
The X in the upper-right corner closes the entire program.

GITHUB UPDATES
The installed program checks a public GitHub repository's Releases page for updates.
It is preconfigured for m404ntfd/foldercreator. Open Settings > Updates to test
the connection or change the details. See GITHUB-UPDATE-SETUP.txt for the
complete release instructions. The expected update asset is ShirtFolderSetup.exe.

SETTINGS LOCATION
The program stores its settings and creation history in:
%APPDATA%\ShirtDesignFolderBuilder\settings.json

BACKUP TIP
Include that settings.json file in normal computer backups. It contains the
category numbers and design-number history.
