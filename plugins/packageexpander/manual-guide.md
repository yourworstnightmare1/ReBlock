# packageExpander: the manual way
This is a guide on how to use packageExpander without our provided script.

**Step 1**: Get the directory of your package. This can be done by control-clicking or right-clicking the file and selecting "Get Info". The path should be next to the "Where" text. You'll need your path in this format: `/directory/path/here/`. For example, instead of "Macintosh HD • Users • joe • Desktop • Installer.pkg", the path will be `~/Desktop/Installer.pkg` or `/Users/joe/Desktop/Installer.pkg`. Then make a new folder, get the path, then delete it. This is because it will break the script if it exists.

**Step 2**: Open a new Terminal window. Type the following: `pkgutil --expand /your/app/dir/here /folder/dir/here`.

**Step 3**: Now there should be a new folder where your folder directory was. Go to it. There should be a new package file there. Control-click or right-click and select "Show Package Contents...". Copy the directory of the file named "Payload". Then make a new folder, but keep it this time. Get the directory of that folder.

**Step 4**: Go back to Terminal and type the following: `tar -xvf /payload/dir/here -C /new/folder/dir/here`.

**Step 5**: You'll see lots of text on the screen showing all the files being extracted. This is what the normal installer does, just in the background. Now go to the folder you created, and the app should be there. You should be able to just open it and it will work!