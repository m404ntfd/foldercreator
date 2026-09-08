SHIRT DESIGN FOLDER BUILDER
===========================

Program version: 2.5.0

WINDOW RESIZING AND WINDOWS SNAP
- The program can be freely resized like a standard Windows application.
- Drag the title bar to the left or right edge to snap it to half the screen.
- You can also press Windows key + Left Arrow or Windows key + Right Arrow.
- Narrow windows automatically rearrange the Create and Settings screens so
  controls remain usable. Scroll bars appear when the available height is small.
- The four Create-screen action buttons use a responsive two-by-two grid so
  every button stays inside its panel and resizes with a snapped window.

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
5. Open Settings > Brands & Colors, add each shirt brand, and upload its color
   image files. The file name is used as the initial color name.

SQUARE ITEM LIBRARY IMPORT
- Open Settings > Square Connection and paste a Square production access token.
- The token needs permission to read the Item Library (ITEMS_READ).
- The token is protected with Windows DPAPI for the current Windows user. It is
  not stored in settings.json, GitHub, logs, design history, or design folders.
- Use Test Connection to verify access, then Refresh Square Catalog to download
  the item information used by the Create screen.
- On the Create screen, enter part of an item name and click Search Square. Choose
  a result and click Use Selected Item.
- The item name becomes the design name. A Square parent category becomes the
  program category, and its child category becomes the program subcategory.
- If a matching category or subcategory is not in the program, the program offers
  to add it and assigns the next stable AA or BB number.
- Enabled Square modifier lists whose names include Color, Colors, or Shirt Color
  supply the available colors. These names can be changed under Square Connection.
- Square color names are matched to uploaded files for the brand selected on the
  Create screen. The import reports any Square color without a matching file.
- The downloaded Square catalog is only a local cache. Clearing Created Designs
  history and cache removes it, and it can be downloaded again at any time.

BRAND AND COLOR CATALOG
- Each brand can contain any number of color image files.
- The Upload Color Files button stays directly above the selected brand's color
  list, including when the program is snapped to half of the screen.
- Color files can also be dragged onto the marked drop area or directly onto
  the selected brand's color list.
- After a new brand is created, the program offers to open the upload picker
  immediately.
- Add, rename, and delete brands; upload, rename, replace, open, and delete colors.
- Uploaded catalog files are kept in AppData and survive program updates.
- Deleting catalog content does not remove files already copied to design folders.
- Clearing Created Designs history and cache does not remove the catalog.

CREATING A DESIGN
1. Select a category and subcategory.
2. Enter the design name.
3. Choose a shirt brand from the color dropdown and check the colors that will
   be offered. Switch brands to select additional colors; previous selections
   remain checked and the screen shows the total selected across all brands.
4. Click "Create in Preset Location", or click "Choose Location & Create" for
   a one-time alternate destination.

The Create screen only displays colors for the selected brand, preventing a
large catalog from becoming one long scrolling list. "Select All Shown" checks
the visible brand, while "Clear All Selections" clears every brand.

The selected catalog files are copied into the new design's Colors Offered
folder and named "Brand - Color" while retaining their original file type.

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

Uploaded shirt color files are stored in:
%APPDATA%\ShirtDesignFolderBuilder\BrandCatalog

BACKUP TIP
Include settings.json and the BrandCatalog folder in normal computer backups.
Together they contain category numbers, design-number history, brand/color
names, and uploaded catalog files.

The encrypted Square token is tied to the Windows user and PC. Reconnect Square
after moving the program to another Windows account or computer.
