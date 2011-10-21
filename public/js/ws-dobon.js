/**
 * ws-dobon.js
 * @author pobo380
 */

var UI = {

  /**
   * Audio methods
   */
  "audio" : {

    // -------------------------------------------
    // Load audio resources.
    // -------------------------------------------
    "load" : function(sounds) {
      var ext = "";
      if((new Audio("")).canPlayType("audio/ogg") != "") {
        ext = ".ogg";
      }
      else {
        ext = ".wav";
      }

      var res = {};
      for(var key in sounds) {
        res[key] = new Audio("../sound/" + sounds[key] + ext);
        res[key].autoplay = false;
      }

      return res;
    },
  },


  /**
   * Update screen methods.
   */
  "update" : {

    // -------------------------------------------
    // update round number.
    // -------------------------------------------
    "round" : function(num) {
      $("#round_number").text(num.toString());
    },

    // -------------------------------------------
    // update played_card
    // -------------------------------------------
    "played" : function(card) {
      pos = this.utils.card_string2image(card);
      $("#played_card").css("background-position", pos.x + "px " + pos.y + "px");
    },

    // -------------------------------------------
    // update others infomation.
    // -------------------------------------------
    "others" : function(others, current_id) {
      var player_idx;
      for(player_idx = 0; player_idx < others.length; ++player_idx) {
        if(others[player_idx].id == player.id) {
          break;
        }
      }
      others = others.slice(player_idx).concat(others.slice(0, player_idx));
      others.shift();
      console.log(others);

      var others_names = $(".other_name");
      var others_hands = $(".other_hand");
      for(var idx = 0; idx < others.length; ++idx) {
        $(others_names[idx]).text(others[idx].name);
        $(others_hands[idx]).text(others[idx].hand);

        if(others[idx].hand <= 3) {
          $(others_hands[idx]).addClass("no_more_than_three");
        }
        else {
          $(others_hands[idx]).removeClass("no_more_than_three");
        }
      }

      var others_turn = $("#others_info div");
      for(var idx = 0; idx < others.length; ++idx) {
        if(others[idx].id == current_id) {
          UI.update.game_message(others[idx].name + "のターンです。");
          $(others_turn[idx]).addClass("current_player");
          $("#game_play, #game_pass").button('disable');
        }
        else {
          $(others_turn[idx]).removeClass("current_player");
        }
      }

      if(current_id == player.id) {
        UI.update.game_message("あなたのターンです。");
        $("#game_play, #game_pass").button('enable');
      }
    },

    // -------------------------------------------
    // update Ruling
    // -------------------------------------------
    "ruling" : function(ruling) {
      var txt = "";
      if(ruling.reverse) {
        txt += "リバース "
      }

      if(ruling.specify) {
        var suit;
        switch(ruling.specify) {
          case "H":
            suit = "ハート"; break;
          case "C":
            suit = "クローバー"; break;
          case "S":
            suit = "スペード"; break;
          case "D":
            suit = "ダイヤ"; break;
        }
        txt += "ワイルドカード => " + suit;
      }
;
      $("#ruling_info").text(txt);
    },

    // -------------------------------------------
    // update Player's hand.
    // -------------------------------------------
    "hand" : function(deck) {
      html = '';
      for(var idx = 0; idx < deck.length; ++idx) {
        pos = this.utils.card_string2image(deck[idx]);
        html = html + '<li class="playing_card_img ui-widget-content" style="background-position:' + 
               [pos.x, pos.y].join('px ') + 'px"' + 'val="'+ deck[idx] +'"></li>';
      }
      $("#hand").html(html);
    },

    // -------------------------------------------
    // update game message
    // -------------------------------------------
    "game_message" : function(msg) {
      $("#game_message").text(msg);
    },

    // -------------------------------------------
    // update game message
    // -------------------------------------------
    "ui_message" : function(msg) {
      $("#ui_message").text(msg);
      setTimeout(function(){
        if($("#ui_message").text() == msg)
        $("#ui_message").text("");
      }, 3000);
    },

    // -------------------------------------------
    // show table
    // -------------------------------------------
    "show_table" : function() {
      $("#create_room_container, #room_list_container")
        .hide(1500);
      $("#game_table_container")
        .show(1500);
    },

    /**
     * Utilities to update screen.
     */
    "utils" : {

      // -------------------------------------------
      // card_string2image
      // -------------------------------------------
      "card_string2image" : function(str) {
        var pos  = {x:0, y:0};
        var size = {w:56, h: 80}
        suit = str.charAt(0);

        rate = 0;
        switch(suit) {
          case 'S':
            rate = 0; break;
          case 'H':
            rate = 1; break;
          case 'C':
            rate = 2; break;
          case 'D':
            rate = 3; break;
          case 'F':
            rate = 0; break;
        }
        pos.y = (size.h + 0) * rate * -1;

        num = str.charAt(1);
        rate = 0;
        num_list = [
          '1', '2', '3', '4',
          '5', '6', '7', '8',
          '9', '0', 'J', 'Q', 'K', 'F'
        ];
        for(var i = 0; i < num_list.length; ++i) {
          if(num_list[i] == num) {
            rate = i;
            break;
          }
        }
        pos.x = (size.w + 0) * rate * -1;

        return pos;
      },
    },
  },


  /**
   * Methods to call ws-dobon APIs
   */
  "ajax" : {
    // -------------------------------------------
    // Simple HTTP GET : Show error dialog when server responded NG.
    // -------------------------------------------
    "simple_get" : function(url, data, ok) {
      $.getJSON(url, data, function(json) {
        if(json.status == "NG") {
          UI.show_dialog(json.message);
        }
        else {
          ok(json.message);
        }
      });
    },
  },

  // -------------------------------------------
  // Show server message dialog.
  // -------------------------------------------
  "show_dialog" : function(msg, callback) {
    $("#dialog-message").text(msg);
    $("#dialog-message").dialog({
      modal: true,
      buttons: { OK: function() {
        $(this).dialog("close");
        if(callback != undefined) { callback(); }
      }}
    });
  },

  ////////
  "show_select_suit" : function(ok, cancel) {
    $("#dialog-select-suit").dialog({
      modal: true,
      buttons: { OK: function() {
        $(this).dialog("close");
        if(ok != undefined) { ok(); }
      },
        Cancel: function() {
        $(this).dialog("close");
        if(cancel != undefined) { cancel(); }
        }
      }
    });
  },

  // -------------------------------------------
  // bind Pusher events.
  // -------------------------------------------
  "bind_pusher_events" : function(pusher, room_id, sounds) {
    var channel = pusher.subscribe(room_id.toString());

    /**
     * bind Pusher events
     */
    channel.bind('ready', function(data) {
      console.log('received:' + JSON.stringify(data));
    });

    var update_table = function(data){
      sounds.select_card.play();
      console.log('received:' + JSON.stringify(data));
      $("#game_ready").button('disable');
      UI.update.ruling(data.ruling);
      UI.update.played(data.played[data.played.length-1]);
      UI.update.round(data.round);
      UI.update.others(data.others, data.current_id);
      $.getJSON("player/action/hand", function(hand) {
        UI.update.hand(hand);
      });
    }

    channel.bind('deal', update_table);
    channel.bind('play', update_table);

    channel.bind('agari',function(data) {
      sounds.select_card.play();
      UI.update.game_message('上がり!!');
      setTimeout(function() {
        update_table(data.table);
      }, 3000);
    });

    channel.bind('dobon', function(data) {
      sounds.select_card.play();
      UI.update.game_message('ドボン!!');
      setTimeout(function() {
        update_table(data.table);
      }, 3000);
    });

    channel.bind('pass', function(data) {
      sounds.select_card.play();
      console.log('received:' + JSON.stringify(data));
      UI.update.ruling(data.ruling);
      UI.update.round(data.round);
      UI.update.others(data.others, data.current_id);
      $.getJSON("player/action/hand", function(hand){
        UI.update.hand(hand);
      });
    });
  },

};

/**
 *
 */
$(function() {

  /**
   * Load audio resources
   */
  var sounds = {click: "button16", select_card: "b_043", button: "b_005"};
  sounds = UI.audio.load(sounds);

  /**
   * UI Initialize
   */
  $("#create_room, #join_room, #game_ready, #game_play, #game_dobon, #game_pass, #room_quit").button();
  $("#room_list").selectable();
  $("#hand").selectable({
    selected : function(event, ui) {
      $(ui.selected).css("margin-top", "-10px");
    },
    unselected : function(event, ui) {
      $(ui.unselected).css("margin-top", "0px");
    }
  });

  $("#suits_list").selectable({
    selected : function(event, ui) {
      $(ui.selected).css({fontWeight: "bold", color: "red", backgroundColor: "ddd"})
    },
    unselected : function(event, ui) {
      $(ui.unselected).css({fontWeight: "", color: "", backgroundColor: ""})
    }
  });
  $("#game_table_container").hide();

  /**
   * Pusher
   */
  var get_pusher = function() {
    return new Pusher('cb41fd71f6794c98a6a6');
  }

  /**
   * Bind click events
   */
  $("#create_room").bind('click', function() {
    var create_room = $("#create_room");
    create_room.button('disable');
    $.getJSON("room/create",
              { name: $("#room_name").val() },
      function(data) {
        create_room.button('enable');
        create_room.removeClass("ui-state-hover");
        if(data.status == "NG") {
          UI.show_dialog(data.message);
          return;
        }
        else {
          UI.show_dialog(data.message, function(){
            location.reload();
          });
        }
      });
  });

  $("#join_room").bind('click', function() {
    var join_room = $("#join_room");
    join_room.button('disable');
    $.getJSON("player/join",
              { name:    $("#player_name").val(),
                room_id: $("#room_list .ui-selected span").attr("value") },
      function(data) {
        join_room.button('enable');
        join_room.removeClass("ui-state-hover");
        if(data.status == "NG") {
          UI.show_dialog(data.message);
          return;
        }
        $.getJSON("player/self",{}, function(player){
          window.player = player;
        });
        var pusher = get_pusher();
        UI.bind_pusher_events(pusher, data.room_id, sounds);
        UI.update.show_table();
      });
  });

  $("#game_ready").bind('click', function() {
    game_ready = $("#game_ready");
    game_ready.attr("disabled", true);
    UI.ajax.simple_get("player/ready", {},
                       function(msg) {
                       });
  });

  /**
   * プレイ動作のボタン
   */
  $("#game_play").bind('click', function(){
    sounds.button.play();

    /* スートの選択 */
    var card = $("#hand .ui-selected").attr("val");
    if(card == undefined) {
      UI.update.ui_message("カードを選択して下さい。");
      return;
    }

    var game_play = $("#game_play");
    game_play.button('disable');

    var send_request = function() {
      var suit = $("#suits_list .ui-selected").attr("val");
      $.getJSON("player/action/play",
                { card: card, specify: suit},
                function(data) {
                  if(data.status == "NG") {
                    UI.update.ui_message(data.message);
                    game_play.button('enable');
                    game_play.removeClass("ui-state-hover");
                  }
                  else {
                    game_play.removeClass("ui-state-hover");
                    if($("#hand li").length == 1) {
                      setTimeout(function() {
                        UI.ajax.simple_get("player/action/agari", {}, function(msg) {
                        });
                      }, 5000);
                    }
                  }
                });
    };

    var cancel = function() {
      game_play.button('enable');
      game_play.removeClass("ui-state-hover");
    };

    if(card == "FF" || card.charAt(1) == "J") {
      UI.show_select_suit(send_request, cancel);
    }
    else {
      send_request();
    }
  });

  $("#game_pass").bind('click', function(){
    var game_pass = $("#game_pass");
    game_pass.button('disable');

    sounds.button.play();
    UI.update.ui_message("パスしました");
    $.getJSON("player/action/pass",
              function(data) {
                game_pass.removeClass("ui-state-hover");
                if(data.status == "NG") {
                  UI.update.ui_message(data.message);
                  game_pass.button('enable');
                }
              });
  });

  $("#game_dobon").bind('click', function(){
    var game_dobon = $("#game_dobon");
    game_dobon.button('disable');

    sounds.button.play();
    UI.update.ui_message("ドボンしました");
    $.getJSON("player/action/dobon",
              function(data) {
                game_dobon.button('enable');
                game_dobon.removeClass("ui-state-hover");
                if(data.status == "NG") {
                  UI.update.ui_message(data.message);
                }
              });
  });

  $("#room_quit").bind('click', function() {
    $("#dialog-quit-confirm").dialog({
      modal: true,
      buttons: { はい: function() {
          UI.ajax.simple_get("player/quit", {},
                             function(msg) {
                               location.reload();
                             });
          $(this).dialog("close");
        },
        いいえ: function() {
          $(this).dialog("close");
        }
      }
    });
  });

  // メニュー選択時のクリック音
  $("#create_room_container .menu-title a").bind("click", function() {
    sounds.click.play();
    $(this).parent().next().toggle(500);
    $("#room_list_container").slideDown(500);
  });

  /**
   * 入室しているかどうか
   */
  if(player != undefined) {
    var pusher = get_pusher();
    UI.bind_pusher_events(pusher, player.room_id, sounds);

    /**
     * ゲームが開始しているかどうか
     */
    if(table != undefined) {
      UI.update.game_message("ゲーム開始");
      $("#game_ready").button('disable');
      UI.update.played(table.played[table.played.length-1]);
      UI.update.round(table.round);
      UI.update.others(table.others, table.current_id);
    }
    else {
      UI.update.game_message("待機中...");
      $("#game_pass, #game_dobon, #game_ready").button('disable');
      $("#game_ready").button('enable');
    }

    UI.update.show_table();

    if(player.hand != "") {
      UI.update.hand(player.hand);
    }
    console.log("入室済み");
  }
  else {
    console.log("入室していない");
  }
});
