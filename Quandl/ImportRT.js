var AmiBroker = new ActiveXObject( "Broker.Application" );

//ab.LoadDatabase("");


function Import( myfilename )
{
AmiBroker.Visible = true;
AmiBroker.Import( 0, myfilename, "quandl.format" );//define format file
}

var dataFolder = "Data\\";// set source data file(s) folder

var fso, fh, fc, filename;

//FileSystemObject
fso = new ActiveXObject("Scripting.FileSystemObject");

// Iterate through all files in the folder
fh = fso.GetFolder( dataFolder );
fc = new Enumerator(fh.files);
for (; !fc.atEnd(); fc.moveNext())
{
filename = "" + fc.item();
Import(filename);
}
AmiBroker.RefreshAll();
AmiBroker.SaveDatabase();

//var Shell = new ActiveXObject("WScript.Shell");//notify user when import is finished
//Shell.Popup("Import Completed", 2.5);
