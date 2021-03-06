/*  This file is part of corebird, a Gtk+ linux Twitter client.
 *  Copyright (C) 2013 Timm Bäder
 *
 *  corebird is free software: you can redistribute it and/or modify
 *  it under the terms of the GNU General Public License as published by
 *  the Free Software Foundation, either version 3 of the License, or
 *  (at your option) any later version.
 *
 *  corebird is distributed in the hope that it will be useful,
 *  but WITHOUT ANY WARRANTY; without even the implied warranty of
 *  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 *  GNU General Public License for more details.
 *
 *  You should have received a copy of the GNU General Public License
 *  along with corebird.  If not, see <http://www.gnu.org/licenses/>.
 */

using Gtk;

class HomeTimeline : IPage, ITimeline, IMessageReceiver, ScrollWidget {
  private bool inited = false;
  public int unread_count                { get; set; }
  public unowned MainWindow main_window  { set; get; }
  protected Gtk.ListBox tweet_list       { set; get; }
  public Account account                 { get; set; }
  private int id;
  private BadgeRadioToolButton tool_button;
  private bool loading = false;
  public int64 lowest_id {get; set; default = int64.MAX-2;}
  protected uint tweet_remove_timeout{get;set;}
  protected int64 max_id { get; set; default = 0; }
  private ProgressEntry progress_entry = new ProgressEntry(75);
  public DeltaUpdater delta_updater {get;set;}

  public HomeTimeline(int id) {
    this.id = id;
    tweet_list = new Gtk.ListBox();
    tweet_list.get_style_context().add_class("stream");
    tweet_list.set_selection_mode(SelectionMode.NONE);
    tweet_list.set_sort_func (ITwitterItem.sort_func);
    this.add (tweet_list);

    this.scrolled_to_end.connect (() => {
      if (!loading) {
        loading = true;
        load_older();
      }
    });

    this.scrolled_to_start.connect (handle_scrolled_to_start);

    this.vadjustment.notify["value"].connect (() => {
      mark_seen_on_scroll (vadjustment.value);
      update_unread_count ();
    });

    tweet_list.activate_on_single_click = false;
    tweet_list.row_activated.connect ((row) => {
      main_window.switch_page (MainWindow.PAGE_TWEET_INFO,
                               TweetInfoPage.BY_INSTANCE,
                               ((TweetListEntry)row).tweet);
    });


    tweet_list.add (progress_entry);
  }

  private void stream_message_received (StreamMessageType type, Json.Node root) { // {{{
    if (type == StreamMessageType.TWEET) {
      GLib.DateTime now = new GLib.DateTime.now_local ();
      Tweet t = new Tweet();
      t.load_from_json (root, now);

      if (t.is_retweet) {
        if (t.retweeted_by == account.name)
          return;

        bool rt_found = false;
        // Check if the original tweet already exists in the timeline
        tweet_list.@foreach ((w) => {
          var tle = (TweetListEntry) w;
          if (tle.tweet.id == t.rt_id || tle.tweet.rt_id == t.rt_id)
            rt_found = true;
        });

        if (rt_found) return;
      }

      // Somebody retweeted the user
      if (t.user_id == account.id && t.is_retweet)
        return;

      this.balance_next_upper_change (TOP);
      if (this.scrolled_up && (t.user_id == account.id ||
          Settings.auto_scroll_on_new_tweets ())) {
        this.scroll_up_next ();
      }

      if (main_window.cur_page_id != this.id ||
          !Settings.auto_scroll_on_new_tweets () ||
          !this.scrolled_up) {
        unread_count++;
        update_unread_count ();
      }


      var entry = new TweetListEntry(t, main_window, account);
      entry.seen = Settings.auto_scroll_on_new_tweets ();
      delta_updater.add (entry);
      tweet_list.add(entry);

      this.max_id = t.id;

      int stack_size = Settings.get_tweet_stack_count ();
      message ("Stack size: %d", stack_size);
      if (stack_size != 0 && unread_count % stack_size == 0) {
        string summary = _("%d new Tweets!").printf (unread_count);
        NotificationManager.notify (summary);
      }

    } else if (type == StreamMessageType.DELETE) {
      int64 id = root.get_object ().get_object_member ("delete")
                     .get_object_member ("status").get_int_member ("id");
      tweet_list.forall ((w) => {
        var tle = (TweetListEntry) w;
        if (tle.tweet.id == id) {
          if (!tle.seen) {
            tweet_list.remove (tle);
            unread_count --;
            update_unread_count ();
          }else
            tle.sensitive = false;
        }
      });
    }
  } // }}}


  /**
   * see IPage#onJoin
   */
  public void on_join (int page_id, va_list arg_list) {
    if (!inited) {
      load_newest ();
      inited = true;
    }

    if (Settings.auto_scroll_on_new_tweets ()) {
      this.unread_count = 0;
      update_unread_count ();
    }
  }

  public void on_leave () {

  }

  public void load_cached() {}

  public void load_newest() {
    this.loading = true;
    this.load_newest_internal.begin("1.1/statuses/home_timeline.json", Tweet.TYPE_NORMAL, () => {
      tweet_list.remove(progress_entry);
      progress_entry = null;
      this.loading = false;
    });
  }

  public void load_older() {
    this.loading = true;
    this.balance_next_upper_change (BOTTOM);
    main_window.start_progress ();
    this.load_older_internal.begin ("1.1/statuses/home_timeline.json", Tweet.TYPE_NORMAL, () => {
      this.loading = false;
      main_window.stop_progress ();
    });
  }


  public void create_tool_button(RadioToolButton? group) {
    tool_button = new BadgeRadioToolButton(group, "corebird-stream-symbolic");
    tool_button.label = "Home";
  }

  public RadioToolButton? get_tool_button() {
    return tool_button;
  }

  public int get_id() {
    return id;
  }

  private void update_unread_count() {
    tool_button.show_badge = (unread_count > 0);
    tool_button.queue_draw();
  }
}
