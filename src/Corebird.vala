
using Gtk;
// TODO: Profile startup when adding e.g. 300 tweets.
class Corebird : Gtk.Application {
	public static SQLHeavy.Database db;

	public Corebird() throws GLib.Error{
		GLib.Object(application_id: "org.baedert.corebird",
		            flags: ApplicationFlags.FLAGS_NONE);
		this.register_session = true;
		this.register();

		// If the user wants the dark theme, apply it
		if(Settings.use_dark_theme()){

		}


		//Create the database needed almost everywhere
		try{
			Corebird.db = new SQLHeavy.Database("Corebird.db");
		}catch(SQLHeavy.Error e){
			error("SQL ERROR: "+e.message);
		}

		stdout.printf("SQLite version: %d\n", SQLHeavy.Version.sqlite_library());

		Twitter.init();



		if (Settings.is_first_run())
		    this.add_window(new FirstRunWindow());
		else
			this.add_window(new MainWindow());


		this.activate.connect( ()  => {});
	}

	/**
	 * Creates the tables in the SQLite database
	 */
	public static void create_tables(){
		try{
			db.execute("CREATE TABLE IF NOT EXISTS `common`(token VARCHAR(255), 
				token_secret VARCHAR(255));");
			db.execute("CREATE TABLE IF NOT EXISTS `cache`(id INTEGER(11), text VARCHAR(140),
					user_id INTEGR(11), user_name VARCHAR(100),  time INTEGER(11), is_retweet BOOL,
			           retweeted_by VARCHAR(100), retweeted BOOL, favorited BOOL, created_at VARCHAR(30),
			           avatar_url VARCHAR(255), retweets INTEGER(5), favorites INTEGER(5),
			           added_to_stream INTEGER(11));");
			// TODO: Avatar URL for avatar refreshing
			// TODO: retweets&favorites!
		}catch(SQLHeavy.Error e){
			error("Error while creating the tables: %s".printf(e.message));
		}
	}
}


int main (string[] args){
	 Gtk.init(ref args);

	try{
		Settings.init();
		new Utils(); //no initialisation of static fields :(
		var corebird = new Corebird();
		corebird.run(args);
	} catch(GLib.Error e){
		stderr.printf(e.message+"\n");
		return -1;
	}

	//TODO: Find out if this information is relative to the user's time zone
	string given = "Wed Jun 20 19:01:28 +0000 2012";
	Utils.parse_date(given);

	

	return 0;
}