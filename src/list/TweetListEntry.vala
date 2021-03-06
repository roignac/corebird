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


[GtkTemplate (ui = "/org/baedert/corebird/ui/tweet-list-entry.ui")]
class TweetListEntry : ITwitterItem, ListBoxRow {
  [GtkChild]
  private Label screen_name_label;
  [GtkChild]
  private TextButton name_button;
  [GtkChild]
  private Label time_delta_label;
  [GtkChild]
  private Image avatar_image;
  [GtkChild]
  private Label text_label;
  [GtkChild]
  private Label rt_label;
  [GtkChild]
  private Revealer reply_revealer;
  [GtkChild]
  private ReplyEntry reply_entry;
  [GtkChild]
  private Label conversation_label;
  [GtkChild]
  private Box text_box;
  [GtkChild]
  private Box hover_box;
  [GtkChild]
  private ToggleButton retweet_button;
  [GtkChild]
  private ToggleButton favorite_button;
  [GtkChild]
  private Button reply_button;
  [GtkChild]
  private MenuButton more_button;
  [GtkChild]
  private Gtk.Menu more_menu;
  [GtkChild]
  private Gtk.MenuItem more_menu_delete_item;



  public int64 sort_factor{
    get{ return tweet.created_at;}
  }
  public bool seen {get; set; default = true;}
  private weak Account account;
  private weak MainWindow window;
  public Tweet tweet;
  private bool values_set = false;
  [Signal (action = true)]
  private signal void show_inline_reply ();
  [Signal (action = true)]
  private signal void hide_inline_reply ();
  [Signal (action = true)]
  private signal void favorite_tweet ();
  [Signal (action = true)]
  private signal void retweet_tweet ();
  [Signal (action = true)]
  private signal void delete_tweet ();


  public TweetListEntry (owned Tweet tweet, MainWindow? window, Account account){
    this.account = account;
    this.tweet = tweet;
    this.window = window;

    name_button.set_markup (tweet.user_name);
    screen_name_label.label = "@"+tweet.screen_name;
    avatar_image.pixbuf = tweet.avatar;
    text_label.label = tweet.get_formatted_text ();
    update_time_delta ();
    reply_entry.text = "@"+tweet.screen_name+" ";
    reply_entry.max_length = Tweet.MAX_LENGTH;
    if (tweet.is_retweet) {
      rt_label.show ();
      rt_label.label = "RT by "+tweet.retweeted_by;
    }


    retweet_button.visible = tweet.retweeted;
    if (tweet.retweeted) {
      retweet_button.active = true;
    }

    favorite_button.visible = tweet.favorited;
    if (tweet.favorited) {
      favorite_button.show();
      favorite_button.active = true;
    }

    // If the avatar gets loaded, we want to change it here immediately
    tweet.notify["avatar"].connect (avatar_changed);

    tweet.inline_media_added.connect (inline_media_added_cb);

    if (tweet.media_thumb != null) {
      var inline_button = new PixbufButton ();
      try {
        inline_button.set_bg (new Gdk.Pixbuf.from_file (tweet.media_thumb));
      } catch (GLib.Error e) {
        warning (e.message);
        return;
      }
      text_box.pack_end (inline_button, false, false);
      inline_button.valign = Align.START;
      inline_button.clicked.connect(inline_media_button_clicked_cb);
      inline_button.show ();
    }

    if (tweet.reply_id != 0) {
      conversation_label.show ();
    }

    more_menu_delete_item.visible = tweet.user_id == account.id;


    reply_entry.focus_in_event.connect(() => {
      reply_revealer.reveal_child = true;
      return false;
    });
    reply_entry.focus_out_event.connect(() => {
      reply_revealer.reveal_child = false;
      return false;
    });
    hover_box.show ();

    reply_entry.cancelled.connect (() => {
      reply_revealer.reveal_child = false;
      this.grab_focus ();
    });
    reply_entry.activate.connect (reply_send_button_clicked_cb);
    show_inline_reply.connect (() => {
      reply_revealer.reveal_child = true;
      reply_entry.grab_focus ();
    });
    delete_tweet.connect (delete_tweet_activated);
    favorite_tweet.connect (() => {
      if (favorite_button.parent != null)
        favorite_button.active = !favorite_button.active;
    });
    retweet_tweet.connect (() => {
      if (retweet_button.parent != null)
        retweet_button.active = !retweet_button.active;
    });

    values_set = true;
  }

  private void delete_tweet_activated () {
    if (tweet.user_id != account.id)
      return; // Nope.
    // TODO: Show confirmation dialog
    TweetUtils.delete_tweet.begin (account, tweet, () => {
        sensitive = false;
    });
  }

  private void avatar_changed () {
    avatar_image.pixbuf = tweet.avatar;
    avatar_image.queue_draw ();
  }

  private void inline_media_added_cb (Gdk.Pixbuf? pic) {
    var inline_button = new PixbufButton ();
    inline_button.set_bg (pic);
    text_box.pack_end (inline_button, false, false);
    inline_button.valign = Align.START;
    inline_button.clicked.connect(inline_media_button_clicked_cb);
    inline_button.show ();
  }

  private void inline_media_button_clicked_cb () {
    ImageDialog id = new ImageDialog(window, tweet.media);
    id.show_all();
  }

  static construct {
    unowned BindingSet binding_set = Gtk.BindingSet.by_class (typeof (TweetListEntry).class_ref ());

    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.r, 0,      "show-inline-reply", 0, null);
    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.Return, 0, "activate", 0, null);
    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.d, 0,      "delete-tweet", 0, null);
    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.t, 0,      "retweet-tweet", 0, null);
    Gtk.BindingEntry.add_signal (binding_set, Gdk.Key.f, 0,      "favorite-tweet", 0, null);
    // TODO: Add q shortcut
  }

  [GtkCallback]
  private void state_flags_changed_cb () { //{{{
    Gtk.StateFlags flags = this.get_state_flags ();
    bool buttons_visible = (bool)(flags & (StateFlags.PRELIGHT | StateFlags.SELECTED));
    buttons_visible = (buttons_visible || more_menu.visible) && !reply_revealer.reveal_child;
    if (buttons_visible) {
      retweet_button.show();
      favorite_button.show();
      reply_button.show();
      more_button.show();
      if (account.id == tweet.user_id) {
        retweet_button.hide();
      }
    } else {
        retweet_button.visible = tweet.retweeted;
        favorite_button.visible = tweet.favorited;
        reply_button.hide();
        more_button.hide();
    }
  } //}}}

  [GtkCallback]
  private bool focus_out_cb (Gdk.EventFocus evt) {
    reply_revealer.reveal_child = false;
    return false;
  }


  [GtkCallback]
  private bool key_released_cb (Gdk.EventKey evt) {
    switch(evt.keyval) {
#if __DEV
      case Gdk.Key.k:
        stdout.printf (tweet.json_data+"\n");
        return true;
#endif
    }
    return false;
  }

  /**
   * Retweets or un-retweets the tweet.
   */
  [GtkCallback]
  private void retweet_button_toggled () { // {{{
    // You can't retweet your own tweets.
    if (account.id == this.tweet.user_id || !values_set)
      return;
    var spinner = new Spinner();

    spinner.start ();
    WidgetReplacer.replace_tmp (retweet_button, spinner);
    spinner.show ();
    TweetUtils.toggle_retweet_tweet.begin (account, tweet, !retweet_button.active, () => {
      WidgetReplacer.replace_tmp_back(retweet_button);
      retweet_button.visible = retweet_button.active;
    });

  } // }}}

  [GtkCallback]
  private void favorite_button_toggled () { // {{{
    if (!values_set)
      return;

    var spinner = new Spinner();
    spinner.start();
    WidgetReplacer.replace_tmp(favorite_button, spinner);
    spinner.show ();
    TweetUtils.toggle_favorite_tweet.begin (account, tweet, !favorite_button.active, () => {
      WidgetReplacer.replace_tmp_back(favorite_button, true,
                                      favorite_button.active);
      favorite_button.visible = favorite_button.active;
    });
  } // }}}

  [GtkCallback]
  private void name_button_clicked_cb () {
    window.switch_page (MainWindow.PAGE_PROFILE,
                        tweet.user_id);
  }

  [GtkCallback]
  private void reply_send_button_clicked_cb () {
    string text = reply_entry.text;
    if (text.strip().length > 0){
      TweetUtils.reply_to_tweet.begin (account, tweet, text);
    }

    this.grab_focus ();
    reply_revealer.reveal_child = false;
  }

  [GtkCallback]
  private void reply_button_clicked_cb () {
    ComposeTweetWindow ctw = new ComposeTweetWindow(this.window, this.account, this.tweet,
                                                    ComposeTweetWindow.Mode.REPLY);
    ctw.show ();
  }

  [GtkCallback]
  private void detail_item_activated_cb () {
    window.switch_page (MainWindow.PAGE_TWEET_INFO,
                        TweetInfoPage.BY_INSTANCE,
                        tweet);
  }

  [GtkCallback]
  private void quote_item_activated_cb () {
    ComposeTweetWindow ctw = new ComposeTweetWindow(this.window, this.account, this.tweet,
                                                    ComposeTweetWindow.Mode.QUOTE);
    ctw.show ();

  }

  [GtkCallback]
  private void delete_item_activated_cb () {
    delete_tweet ();
  }

  [GtkCallback]
  private bool link_activated_cb (string uri) {
    return TweetUtils.activate_link (uri, window);
  }


  /**
   * Updates the time delta label in the upper right
   *
   * @return The seconds between the current time and
   *         the time the tweet was created
   */
  public int update_time_delta (GLib.DateTime? now = null) { //{{{
    GLib.DateTime cur_time;
    if (now == null)
      cur_time = new GLib.DateTime.now_local ();
    else
      cur_time = now;

    GLib.DateTime then = new GLib.DateTime.from_unix_local (
                 tweet.is_retweet ? tweet.rt_created_at : tweet.created_at);
    string link = "https://twitter.com/%s/status/%s".printf (tweet.screen_name,
                                                             tweet.id.to_string());
    time_delta_label.label = "<small><a href='%s' title='Open in Browser'>%s</a></small>"
                  .printf (link, Utils.get_time_delta (then, cur_time));
    return (int)(cur_time.difference (then) / 1000.0 / 1000.0);
  } //}}}

  public override bool draw (Cairo.Context c) { //{{{
    var style = this.get_style_context();
    int w = get_allocated_width();
    int h = get_allocated_height();
    style.render_background(c, 0, 0, w, h);

    var border_color = style.get_border_color(get_state_flags());
    c.set_source_rgba(border_color.red, border_color.green, border_color.blue,
                      border_color.alpha);

    // The line here is 50% of the width
    c.move_to(w*0.25, h);
    c.line_to(w*0.75, h);
    c.stroke();

    base.draw(c);
    return false;
  } //}}}

}
