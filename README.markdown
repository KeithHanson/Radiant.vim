What is this?
===================

This is a Vim plugin used to edit RadiantCMS content directly in vim, instead of constantly hopping back and forth between your browser tabs.

For those of us that do lots of RadiantCMS installs, you quickly tire of not being able to edit the content in your favorite editor.

How do I set it up?
===================

At the moment, the require statement is hard-coded into the "plugin". You must set the environment and require path to your RadiantCMS application for this to function properly.

How do I use it?
==================

:Radiant [edit|split|vsplit] [pages|layouts|snippets]/content

For example:

:Radiant edit layouts/main

:Radiant vsplit pages/home

Calling :w will write the content back out to your database.

Current Status
==================
This initial commit is literally a copy and paste from the the internet archive where I found this script. 

It has since been abandoned, but original credit seems like it should be for this particular person: http://www.raphinou.com/
