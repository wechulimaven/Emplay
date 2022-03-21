// ignore_for_file: avoid_redundant_argument_values, prefer_single_quotes, sort_child_properties_last, require_trailing_commas

import 'dart:io';
import 'dart:math';

import 'package:blackhole/CustomWidgets/custom_physics.dart';
import 'package:blackhole/CustomWidgets/data_search.dart';
import 'package:blackhole/CustomWidgets/empty_screen.dart';
import 'package:blackhole/CustomWidgets/gradient_containers.dart';
import 'package:blackhole/CustomWidgets/miniplayer.dart';
import 'package:blackhole/CustomWidgets/snackbar.dart';
import 'package:blackhole/CustomWidgets/textinput_dialog.dart';
import 'package:blackhole/Helpers/audio_query.dart';
import 'package:blackhole/Helpers/backup_restore.dart';
import 'package:blackhole/Helpers/supabase.dart';
import 'package:blackhole/Screens/Home/saavn.dart';
import 'package:blackhole/Screens/Library/library.dart';
import 'package:blackhole/Screens/LocalMusic/downed_songs.dart';
import 'package:blackhole/Screens/Search/search.dart';
import 'package:blackhole/Screens/Settings/setting.dart';
import 'package:blackhole/Screens/Top Charts/top.dart';
import 'package:blackhole/Screens/YouTube/youtube_home.dart';
import 'package:blackhole/Screens/YouTube/youtube_search.dart';
import 'package:blackhole/Services/ext_storage_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:package_info/package_info.dart';
import 'package:path_provider/path_provider.dart';
import 'package:salomon_bottom_bar/salomon_bottom_bar.dart';
import 'package:url_launcher/url_launcher.dart';

List globalItems = [];

List cachedGlobalItems = [];
bool fetched = false;

bool emptyGlobal = false;

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ValueNotifier<int> _selectedIndex = ValueNotifier<int>(0);
  bool checked = false;
  String? appVersion;
  String name =
      Hive.box('settings').get('name', defaultValue: 'Guest') as String;
  bool checkUpdate =
      Hive.box('settings').get('checkUpdate', defaultValue: false) as bool;
  bool autoBackup =
      Hive.box('settings').get('autoBackup', defaultValue: false) as bool;
  DateTime? backButtonPressTime;

  String capitalize(String msg) {
    return '${msg[0].toUpperCase()}${msg.substring(1)}';
  }

  void callback() {
    setState(() {});
  }

  void _onItemTapped(int index) {
    _selectedIndex.value = index;
    _pageController.jumpToPage(
      index,
    );
  }

  bool compareVersion(String latestVersion, String currentVersion) {
    bool update = false;
    final List latestList = latestVersion.split('.');
    final List currentList = currentVersion.split('.');

    for (int i = 0; i < latestList.length; i++) {
      try {
        if (int.parse(latestList[i] as String) >
            int.parse(currentList[i] as String)) {
          update = true;
          break;
        }
      } catch (e) {
        break;
      }
    }
    return update;
  }

  void updateUserDetails(String key, dynamic value) {
    final userId = Hive.box('settings').get('userId') as String?;
    SupaBase().updateUserDetails(userId, key, value);
  }

  Future<bool> handleWillPop(BuildContext context) async {
    final now = DateTime.now();
    final backButtonHasNotBeenPressedOrSnackBarHasBeenClosed =
        backButtonPressTime == null ||
            now.difference(backButtonPressTime!) > const Duration(seconds: 3);

    if (backButtonHasNotBeenPressedOrSnackBarHasBeenClosed) {
      backButtonPressTime = now;
      ShowSnackBar().showSnackBar(
        context,
        AppLocalizations.of(context)!.exitConfirm,
        duration: const Duration(seconds: 2),
        noAction: true,
      );
      return false;
    }
    return true;
  }

  Widget checkVersion() {
    if (!checked && Theme.of(context).platform == TargetPlatform.android) {
      checked = true;
      final SupaBase db = SupaBase();
      final DateTime now = DateTime.now();
      final List lastLogin = now
          .toUtc()
          .add(const Duration(hours: 5, minutes: 30))
          .toString()
          .split('.')
        ..removeLast()
        ..join('.');
      updateUserDetails('lastLogin', '${lastLogin[0]} IST');
      final String offset =
          now.timeZoneOffset.toString().replaceAll('.000000', '');

      updateUserDetails(
        'timeZone',
        'Zone: ${now.timeZoneName}, Offset: $offset',
      );

      PackageInfo.fromPlatform().then((PackageInfo packageInfo) {
        appVersion = packageInfo.version;
        updateUserDetails('version', packageInfo.version);

        if (checkUpdate) {
          db.getUpdate().then((Map value) {
            if (compareVersion(value['LatestVersion'] as String, appVersion!)) {
              ShowSnackBar().showSnackBar(
                context,
                AppLocalizations.of(context)!.updateAvailable,
                duration: const Duration(seconds: 15),
                action: SnackBarAction(
                  textColor: Theme.of(context).colorScheme.secondary,
                  label: AppLocalizations.of(context)!.update,
                  onPressed: () {
                    Navigator.pop(context);
                    launch(value['LatestUrl'] as String);
                  },
                ),
              );
            }
          });
        }
        if (autoBackup) {
          final List<String> checked = [
            AppLocalizations.of(
              context,
            )!
                .settings,
            AppLocalizations.of(
              context,
            )!
                .downs,
            AppLocalizations.of(
              context,
            )!
                .playlists,
          ];
          final List playlistNames = Hive.box('settings').get(
            'playlistNames',
            defaultValue: ['Favorite Songs'],
          ) as List;
          final Map<String, List> boxNames = {
            AppLocalizations.of(
              context,
            )!
                .settings: ['settings'],
            AppLocalizations.of(
              context,
            )!
                .cache: ['cache'],
            AppLocalizations.of(
              context,
            )!
                .downs: ['downloads'],
            AppLocalizations.of(
              context,
            )!
                .playlists: playlistNames,
          };
          ExtStorageProvider.getExtStorage(dirName: 'BlackHole/Backups')
              .then((value) {
            createBackup(
              context,
              checked,
              boxNames,
              path: value,
              fileName: 'BlackHole_AutoBackup',
              showDialog: false,
            );
          });
        }
      });
      if (Hive.box('settings').get('proxyIp') == null) {
        Hive.box('settings').put('proxyIp', '103.47.67.134');
      }
      if (Hive.box('settings').get('proxyPort') == null) {
        Hive.box('settings').put('proxyPort', 8080);
      }
      return const SizedBox();
    } else {
      return const SizedBox();
    }
  }

  final ScrollController _scrollController = ScrollController();
  final PageController _pageController = PageController();

  List<SongModel> _songs = [];
  String? tempPath = Hive.box('settings').get('tempDirPath')?.toString();
  final Map<String, List<SongModel>> _albums = {};
  final Map<String, List<SongModel>> _artists = {};
  final Map<String, List<SongModel>> _genres = {};

  final List<String> _sortedAlbumKeysList = [];
  final List<String> _sortedArtistKeysList = [];
  final List<String> _sortedGenreKeysList = [];
  OfflineAudioQuery offlineAudioQuery = OfflineAudioQuery();

  final Map<int, SongSortType> songSortTypes = {
    0: SongSortType.DISPLAY_NAME,
    1: SongSortType.DATE_ADDED,
    2: SongSortType.ALBUM,
    3: SongSortType.ARTIST,
    4: SongSortType.DURATION,
    5: SongSortType.SIZE,
  };
  final Map<int, OrderType> songOrderTypes = {
    0: OrderType.ASC_OR_SMALLER,
    1: OrderType.DESC_OR_GREATER,
  };
  int minDuration =
      Hive.box('settings').get('minDuration', defaultValue: 10) as int;
  int sortValue = Hive.box('settings').get('sortValue', defaultValue: 1) as int;
  int orderValue =
      Hive.box('settings').get('orderValue', defaultValue: 1) as int;

  @override
  void initState() {
    getCached();
    getCachedData();
    getData();
    super.initState();
  }

  Future<void> getCachedData() async {
    cachedGlobalItems =
        await Hive.box('cache').get("global", defaultValue: []) as List;

    setState(() {});
  }

  Future<void> getData() async {
    fetched = true;
    final List temp = await compute(scrapData, "global");
    setState(() {
      globalItems = temp;
      if (globalItems.isNotEmpty) {
        cachedGlobalItems = globalItems;
        Hive.box('cache').put("global", globalItems);
      }
      emptyGlobal = globalItems.isEmpty && cachedGlobalItems.isEmpty;
    });
  }

  Future<void> getCached() async {
    await offlineAudioQuery.requestPermission();
    tempPath ??= (await getTemporaryDirectory()).path;
    // if (widget.cachedSongs == null) {
    _songs = (await offlineAudioQuery.getSongs(
      sortType: songSortTypes[sortValue],
      orderType: songOrderTypes[orderValue],
    ))
        .where(
          (i) =>
              (i.duration ?? 60000) > 1000 * minDuration &&
              (i.isMusic! || i.isPodcast! || i.isAudioBook!),
        )
        .toList();
    // } else {
    //   _songs = widget.cachedSongs!;
    // }
    // added = true;
    setState(() {});
    for (int i = 0; i < _songs.length; i++) {
      if (_albums.containsKey(_songs[i].album)) {
        _albums[_songs[i].album]!.add(_songs[i]);
      } else {
        _albums.addEntries([
          MapEntry(_songs[i].album!, [_songs[i]])
        ]);
        _sortedAlbumKeysList.add(_songs[i].album!);
      }

      if (_artists.containsKey(_songs[i].artist)) {
        _artists[_songs[i].artist]!.add(_songs[i]);
      } else {
        _artists.addEntries([
          MapEntry(_songs[i].artist!, [_songs[i]])
        ]);
        _sortedArtistKeysList.add(_songs[i].artist!);
      }

      if (_genres.containsKey(_songs[i].genre)) {
        _genres[_songs[i].genre]!.add(_songs[i]);
      } else {
        _genres.addEntries([
          MapEntry(_songs[i].genre!, [_songs[i]])
        ]);
        _sortedGenreKeysList.add(_songs[i].genre!);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final List showList = cachedGlobalItems;
    final bool isListEmpty = emptyGlobal;
    return GradientContainer(
      child: Scaffold(
        resizeToAvoidBottomInset: false,
        backgroundColor: Colors.transparent,
        // drawer: Drawer(
        //   child: GradientContainer(
        //     child: Column(
        //       mainAxisAlignment: MainAxisAlignment.spaceBetween,
        //       children: [
        //         CustomScrollView(
        //           shrinkWrap: true,
        //           physics: const BouncingScrollPhysics(),
        //           slivers: [
        //             SliverAppBar(
        //               backgroundColor: Colors.transparent,
        //               automaticallyImplyLeading: false,
        //               elevation: 0,
        //               stretch: true,
        //               expandedHeight: MediaQuery.of(context).size.height * 0.2,
        //               flexibleSpace: FlexibleSpaceBar(
        //                 title: RichText(
        //                   text: TextSpan(
        //                     text: AppLocalizations.of(context)!.appTitle,
        //                     style: const TextStyle(
        //                       fontSize: 30.0,
        //                       fontWeight: FontWeight.w500,
        //                     ),
        //                     children: <TextSpan>[
        //                       TextSpan(
        //                         text:
        //                             appVersion == null ? '' : '\nv$appVersion',
        //                         style: const TextStyle(
        //                           fontSize: 7.0,
        //                         ),
        //                       ),
        //                     ],
        //                   ),
        //                   textAlign: TextAlign.end,
        //                 ),
        //                 titlePadding: const EdgeInsets.only(bottom: 40.0),
        //                 centerTitle: true,
        //                 background: ShaderMask(
        //                   shaderCallback: (rect) {
        //                     return LinearGradient(
        //                       begin: Alignment.topCenter,
        //                       end: Alignment.bottomCenter,
        //                       colors: [
        //                         Colors.black.withOpacity(0.8),
        //                         Colors.black.withOpacity(0.1),
        //                       ],
        //                     ).createShader(
        //                       Rect.fromLTRB(0, 0, rect.width, rect.height),
        //                     );
        //                   },
        //                   blendMode: BlendMode.dstIn,
        //                   child: Image(
        //                     fit: BoxFit.cover,
        //                     alignment: Alignment.topCenter,
        //                     image: AssetImage(
        //                       Theme.of(context).brightness == Brightness.dark
        //                           ? 'assets/header-dark.jpg'
        //                           : 'assets/header.jpg',
        //                     ),
        //                   ),
        //                 ),
        //               ),
        //             ),
        //             SliverList(
        //               delegate: SliverChildListDelegate(
        //                 [
        //                   ListTile(
        //                     title: Text(
        //                       AppLocalizations.of(context)!.home,
        //                       style: TextStyle(
        //                         color: Theme.of(context).colorScheme.secondary,
        //                       ),
        //                     ),
        //                     contentPadding:
        //                         const EdgeInsets.symmetric(horizontal: 20.0),
        //                     leading: Icon(
        //                       Icons.home_rounded,
        //                       color: Theme.of(context).colorScheme.secondary,
        //                     ),
        //                     selected: true,
        //                     onTap: () {
        //                       Navigator.pop(context);
        //                     },
        //                   ),
        //                   if (Platform.isAndroid)
        //                     ListTile(
        //                       title:
        //                           Text(AppLocalizations.of(context)!.myMusic),
        //                       contentPadding:
        //                           const EdgeInsets.symmetric(horizontal: 20.0),
        //                       leading: Icon(
        //                         MdiIcons.folderMusic,
        //                         color: Theme.of(context).iconTheme.color,
        //                       ),
        //                       onTap: () {
        //                         Navigator.pop(context);
        //                         Navigator.pushNamed(context, '/mymusic');
        //                       },
        //                     ),
        //                   ListTile(
        //                     title: Text(AppLocalizations.of(context)!.downs),
        //                     contentPadding:
        //                         const EdgeInsets.symmetric(horizontal: 20.0),
        //                     leading: Icon(
        //                       Icons.download_done_rounded,
        //                       color: Theme.of(context).iconTheme.color,
        //                     ),
        //                     onTap: () {
        //                       Navigator.pop(context);
        //                       Navigator.pushNamed(context, '/downloads');
        //                     },
        //                   ),
        //                   ListTile(
        //                     title:
        //                         Text(AppLocalizations.of(context)!.playlists),
        //                     contentPadding:
        //                         const EdgeInsets.symmetric(horizontal: 20.0),
        //                     leading: Icon(
        //                       Icons.playlist_play_rounded,
        //                       color: Theme.of(context).iconTheme.color,
        //                     ),
        //                     onTap: () {
        //                       Navigator.pop(context);
        //                       Navigator.pushNamed(context, '/playlists');
        //                     },
        //                   ),
        //                   ListTile(
        //                     title: Text(AppLocalizations.of(context)!.settings),
        //                     contentPadding:
        //                         const EdgeInsets.symmetric(horizontal: 20.0),
        //                     leading: Icon(
        //                       Icons
        //                           .settings_rounded, // miscellaneous_services_rounded,
        //                       color: Theme.of(context).iconTheme.color,
        //                     ),
        //                     onTap: () {
        //                       Navigator.pop(context);
        //                       Navigator.push(
        //                         context,
        //                         MaterialPageRoute(
        //                           builder: (context) =>
        //                               SettingPage(callback: callback),
        //                         ),
        //                       );
        //                     },
        //                   ),
        //                   ListTile(
        //                     title: Text(AppLocalizations.of(context)!.about),
        //                     contentPadding:
        //                         const EdgeInsets.symmetric(horizontal: 20.0),
        //                     leading: Icon(
        //                       Icons.info_outline_rounded,
        //                       color: Theme.of(context).iconTheme.color,
        //                     ),
        //                     onTap: () {
        //                       Navigator.pop(context);
        //                       Navigator.pushNamed(context, '/about');
        //                     },
        //                   ),
        //                 ],
        //               ),
        //             ),
        //           ],
        //         ),
        //         Padding(
        //           padding: const EdgeInsets.fromLTRB(5, 30, 5, 20),
        //           child: Center(
        //             child: Text(
        //               AppLocalizations.of(context)!.madeBy,
        //               textAlign: TextAlign.center,
        //               style: const TextStyle(fontSize: 12),
        //             ),
        //           ),
        //         ),
        //       ],
        //     ),
        //   ),
        // ),
        body: WillPopScope(
          onWillPop: () => handleWillPop(context),
          child: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: PageView(
                    physics: const CustomPhysics(),
                    onPageChanged: (indx) {
                      _selectedIndex.value = indx;
                    },
                    controller: _pageController,
                    children: [
                      Stack(
                        children: [
                          checkVersion(),
                          NestedScrollView(
                            physics: const BouncingScrollPhysics(),
                            controller: _scrollController,
                            headerSliverBuilder:
                                (BuildContext context, bool innerBoxScrolled) {
                              return <Widget>[
                                // const SliverToBoxAdapter(
                                //   child: SizedBox(
                                //     height: 40,
                                //   ),
                                // ),
                                SliverAppBar(
                                  expandedHeight: 180.0,
                                  floating: false,
                                  elevation: 0.0,
                                  pinned: false,
                                  primary: true,
                                  title: const Text(
                                    "Emplay",
                                    style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 20.0,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 1.0),
                                  ),
                                  backgroundColor: Colors.white30,
                                  leading: Padding(
                                    child: Image.asset(
                                      'assets/ytCover.png',
                                    ),
                                    padding: const EdgeInsets.all(13.0),
                                  ),
                                  actions: <Widget>[
                                    IconButton(
                                      icon: const Icon(
                                        Icons.info_outline,
                                        color: Colors.white,
                                      ),
                                      onPressed: () {
                                        //aboutPart
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.search),
                                      onPressed: () {
                                        //                 showSearch(
                                        //   context: context,
                                        //   delegate: DataSearch(
                                        //     data: _songs,
                                        //     tempPath: tempPath!,
                                        //   ),
                                        // );
                                      },
                                    ),
                                    // })
                                  ],
                                  flexibleSpace: FlexibleSpaceBar(
                                    background: Stack(
                                      fit: StackFit.expand,
                                      children: <Widget>[
                                        // isLoading
                                        //     ?
                                        Image.asset(
                                          'assets/ytCover.png',
                                          fit: BoxFit.fitWidth,
                                        )
                                        // : getImage(last) != null
                                        //     ?  Image.file(
                                        //         getImage(last),
                                        //         fit: BoxFit.cover,
                                        //       )
                                        //     :  Image.asset(
                                        //         "images/back.jpg",
                                        //         fit: BoxFit.fitWidth,
                                        //       ),
                                      ],
                                    ),
                                  ),
                                  systemOverlayStyle:
                                      SystemUiOverlayStyle.light,
                                ),
                                // SliverAppBar(
                                //   automaticallyImplyLeading: false,
                                //   pinned: true,
                                //   backgroundColor: Colors.transparent,
                                //   elevation: 0,
                                //   stretch: true,
                                //   toolbarHeight: 65,
                                //   title: Align(
                                //     alignment: Alignment.centerRight,
                                //     child: AnimatedBuilder(
                                //       animation: _scrollController,
                                //       builder: (context, child) {
                                //         return GestureDetector(
                                //           child: AnimatedContainer(
                                //             width: (!_scrollController
                                //                         .hasClients ||
                                //                     _scrollController
                                //                             // ignore: invalid_use_of_protected_member
                                //                             .positions
                                //                             .length >
                                //                         1)
                                //                 ? MediaQuery.of(context)
                                //                     .size
                                //                     .width
                                //                 : max(
                                //                     MediaQuery.of(context)
                                //                             .size
                                //                             .width -
                                //                         _scrollController.offset
                                //                             .roundToDouble(),
                                //                     MediaQuery.of(context)
                                //                             .size
                                //                             .width -
                                //                         75,
                                //                   ),
                                //             height: 52.0,
                                //             duration: const Duration(
                                //               milliseconds: 150,
                                //             ),
                                //             padding: const EdgeInsets.all(2.0),
                                //             // margin: EdgeInsets.zero,
                                //             decoration: BoxDecoration(
                                //               borderRadius:
                                //                   BorderRadius.circular(10.0),
                                //               color:
                                //                   Theme.of(context).cardColor,
                                //               boxShadow: const [
                                //                 BoxShadow(
                                //                   color: Colors.black26,
                                //                   blurRadius: 5.0,
                                //                   offset: Offset(1.5, 1.5),
                                //                   // shadow direction: bottom right
                                //                 )
                                //               ],
                                //             ),
                                //             child: Row(
                                //               children: [
                                //                 const SizedBox(width: 10.0),
                                //                 Icon(
                                //                   CupertinoIcons.search,
                                //                   color: Theme.of(context)
                                //                       .colorScheme
                                //                       .secondary,
                                //                 ),
                                //                 const SizedBox(width: 10.0),
                                //                 Text(
                                // AppLocalizations.of(
                                //   context,
                                // )!
                                //     .searchText,
                                // style: TextStyle(
                                //   fontSize: 16.0,
                                //   color: Theme.of(context)
                                //       .textTheme
                                //       .caption!
                                //       .color,
                                //                     fontWeight:
                                //                         FontWeight.normal,
                                //                   ),
                                //                 ),
                                //               ],
                                //             ),
                                //           ),
                                //           onTap: () => Navigator.push(
                                //             context,
                                //             MaterialPageRoute(
                                //               builder: (context) =>
                                //                   const SearchPage(
                                //                 query: '',
                                //                 fromHome: true,
                                //               ),
                                //             ),
                                //           ),
                                //         );
                                //       },
                                //     ),
                                //   ),
                                // ),
                              ];
                            },
                            body: //const YouTube(),
                                ListView(
                                  padding: const EdgeInsets.all(4.0),
                              children: <Widget>[
                                const Padding(
                                  padding: EdgeInsets.only(
                                    left: 15.0,
                                    top: 15.0,
                                    bottom: 10.0,
                                  ),
                                  child: Text(
                                    'QUICK ACTIONS',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.0,
                                      letterSpacing: 2.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: <Widget>[
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: <Widget>[
                                        RawMaterialButton(
                                          shape: const CircleBorder(),
                                          fillColor: Colors.transparent,
                                          splashColor: Colors.blueGrey[200],
                                          highlightColor: Colors.blueGrey[200]!
                                              .withOpacity(0.3),
                                          elevation: 15.0,
                                          highlightElevation: 0.0,
                                          disabledElevation: 0.0,
                                          onPressed: () {
                                            // Navigator.of(context).push(
                                            //      MaterialPageRoute(builder: (context) {
                                            //   return  ListSongs(widget.db, 1, orientation);
                                            // }));
                                          },
                                          child: const Icon(
                                            CupertinoIcons.music_albums,
                                            size: 50.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                        ),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!
                                              .favorites,
                                          // 'Favorites',
                                          style: const TextStyle(
                                            fontSize: 12.0,
                                            letterSpacing: 2.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: <Widget>[
                                        RawMaterialButton(
                                          shape: const CircleBorder(),
                                          fillColor: Colors.transparent,
                                          splashColor: Colors.blueGrey[200],
                                          highlightColor: Colors.blueGrey[200]!
                                              .withOpacity(0.3),
                                          elevation: 15.0,
                                          highlightElevation: 0.0,
                                          disabledElevation: 0.0,
                                          onPressed: () {
                                            // Navigator.of(context)
                                            //     .push( MaterialPageRoute(builder: (context) {
                                            //   return  ListSongs(widget.db, 2, orientation);
                                            // }));
                                          },
                                          child: const Icon(
                                            Icons.download_sharp,
                                            size: 50.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                        ),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!
                                              .down,
                                          // "Downloads",
                                          style: const TextStyle(
                                            fontSize: 12.0,
                                            letterSpacing: 2.0,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Column(
                                      children: <Widget>[
                                        RawMaterialButton(
                                          shape: const CircleBorder(),
                                          fillColor: Colors.transparent,
                                          splashColor: Colors.blueGrey[200],
                                          highlightColor: Colors.blueGrey[200]!
                                              .withOpacity(0.3),
                                          elevation: 15.0,
                                          highlightElevation: 0.0,
                                          disabledElevation: 0.0,
                                          onPressed: () {
                                            // Navigator.of(context).push(
                                            //      MaterialPageRoute(builder: (context) {
                                            //   return  NowPlaying(widget.db, songs,
                                            //        Random().nextInt(songs.length), 0);
                                            // },
                                            // ),);
                                          },
                                          child: const Icon(
                                            CupertinoIcons.music_note_list,
                                            size: 50.0,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const Padding(
                                          padding: EdgeInsets.symmetric(
                                            vertical: 8.0,
                                          ),
                                        ),
                                        Text(
                                          AppLocalizations.of(
                                            context,
                                          )!
                                              .playlists,
                                          // 'Playlist',
                                          style: const TextStyle(
                                            fontSize: 12.0,
                                            letterSpacing: 2.0,
                                          ),
                                        )
                                      ],
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.06),

                                // AlbumsTab(
                                //   albums: _artists,
                                //   albumsList: _sortedArtistKeysList,
                                //   tempPath: tempPath!,
                                // ),
                                // AlbumsTab(
                                //   albums: _genres,
                                //   albumsList: _sortedGenreKeysList,
                                //   tempPath: tempPath!,
                                // ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                          bottom: 10.0, right: 0.0),
                                      child: Column(
                                        children: <Widget>[
                                          InkResponse(
                                            child: const SizedBox(
                                              child: Hero(
                                                tag: "topArtist[i].artist",
                                                child: CircleAvatar(
                                                  backgroundImage: AssetImage(
                                                      "assets/back.jpg"),
                                                  radius: 60.0,
                                                ),
                                              ),
                                            ),
                                            onTap: () {
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const DownloadedSongs(),
                                                ),
                                              );
                                            },
                                          ),
                                          SizedBox(
                                            width: 150.0,
                                            child: Padding(
                                              // padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                      0.0, 15.0, 0.0, 0.0),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: <Widget>[
                                                  Center(
                                                    child: Text(
                                                      AppLocalizations.of(
                                                        context,
                                                      )!
                                                          .myMusic,

                                                      // "MY MUSIC",
                                                      style: TextStyle(
                                                          fontSize: 14.0,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          color: Colors.black
                                                              .withOpacity(
                                                                  0.70)),
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 0.0),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    GestureDetector(
                                      onTap: () => Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => AlbumsTab(
                                            isFromHome: true,
                                            albums: _albums,
                                            albumsList: _sortedAlbumKeysList,
                                            tempPath: tempPath!,
                                          ),
                                        ),
                                      ),
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 35.0),
                                        child: Card(
                                          elevation: 12.0,
                                          child: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(6.0),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: <Widget>[
                                                InkResponse(
                                                  child: SizedBox(
                                                    child: Hero(
                                                      tag: 'Top Albums',
                                                      child: Image.asset(
                                                        "assets/back.jpg",
                                                        height: 120.0,
                                                        width: 180.0,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: 180.0,
                                                  child: Padding(
                                                    // padding: EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 8.0),
                                                    padding: const EdgeInsets
                                                            .fromLTRB(
                                                        10.0, 8.0, 0.0, 0.0),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: <Widget>[
                                                        Text(
                                                          AppLocalizations.of(
                                                            context,
                                                          )!
                                                              .albums,
                                                          style: TextStyle(
                                                              fontSize: 12.0,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: Colors
                                                                  .black
                                                                  .withOpacity(
                                                                      0.70)),
                                                          maxLines: 1,
                                                        ),
                                                        const SizedBox(
                                                            height: 5.0),
                                                        Padding(
                                                          padding:
                                                              const EdgeInsetsDirectional
                                                                      .only(
                                                                  bottom: 5.0),
                                                          child: Text(
                                                            AppLocalizations.of(
                                                              context,
                                                            )!
                                                                .albumArtist,
                                                            maxLines: 1,
                                                            style: TextStyle(
                                                                fontSize: 10.0,
                                                                color: Colors
                                                                    .black
                                                                    .withOpacity(
                                                                        0.75)),
                                                          ),
                                                        )
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.01),
                                const Padding(
                                  padding: EdgeInsets.only(
                                    left: 15.0,
                                    top: 15.0,
                                    bottom: 10.0,
                                  ),
                                  child: Text(
                                    'Trending Songs',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15.0,
                                      letterSpacing: 2.0,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                if (showList.length <= 50)
                                  isListEmpty
                                      ? emptyScreen(
                                          context,
                                          0,
                                          ':( ',
                                          100,
                                          'ERROR',
                                          60,
                                          'Service Unavailable',
                                          20,
                                        )
                                      : Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            SizedBox(
                                              height: MediaQuery.of(context)
                                                      .size
                                                      .width /
                                                  7,
                                              width: MediaQuery.of(context)
                                                      .size
                                                      .width /
                                                  7,
                                              child:
                                                  const CircularProgressIndicator(),
                                            ),
                                          ],
                                        )
                                else
                                  GridView.builder(
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    shrinkWrap: true,
                                    padding: const EdgeInsets.all(2.0),
                                    gridDelegate:
                                        const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 3.0,
                                      mainAxisSpacing: 2.0,
                                      mainAxisExtent:105.0
                                    ),
                                    itemCount: 20,
                                    itemBuilder: (context, index) {
                                      return ListTile(
                                        leading: Card(
                                          elevation: 5,
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(7.0),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: Stack(
                                            children: [
                                              const Image(
                                                image: AssetImage(
                                                    'assets/cover.jpg'),
                                              ),
                                              if (showList[index]['image'] !=
                                                  '')
                                                CachedNetworkImage(
                                                  fit: BoxFit.cover,
                                                  imageUrl: showList[index]
                                                          ['image']
                                                      .toString(),
                                                  errorWidget:
                                                      (context, _, __) =>
                                                          const Image(
                                                    fit: BoxFit.cover,
                                                    image: AssetImage(
                                                        'assets/cover.jpg'),
                                                  ),
                                                  placeholder: (context, url) =>
                                                      const Image(
                                                    fit: BoxFit.cover,
                                                    image: AssetImage(
                                                        'assets/cover.jpg'),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        title: Text(
                                          showList[index]['position'] == null
                                              ? '${showList[index]["title"]}'
                                              : '${showList[index]['position']}. ${showList[index]["title"]}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        subtitle: Text(
                                          '${showList[index]['artist']}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        onTap: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  YouTubeSearchPage(
                                                query: showList[index]['title']
                                                    .toString(),
                                              ),
                                              // SearchPage(
                                              //   query: showList[index]['title'].toString(),
                                              // ),
                                            ),
                                          );
                                        },
                                      );
                                    },
                                  )
                              ],
                            ),
                          ),
                          Builder(
                            builder: (context) => Padding(
                              padding:
                                  const EdgeInsets.only(top: 8.0, left: 4.0),
                              child: Transform.rotate(
                                angle: 22 / 7 * 2,
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.horizontal_split_rounded,
                                  ),
                                  // color: Theme.of(context).iconTheme.color,
                                  onPressed: () {
                                    Scaffold.of(context).openDrawer();
                                  },
                                  tooltip: MaterialLocalizations.of(context)
                                      .openAppDrawerTooltip,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      TopCharts(
                        pageController: _pageController,
                      ),
                      const YouTube(),
                      LibraryPage(),
                    ],
                  ),
                ),
                MiniPlayer()
              ],
            ),
          ),
        ),
        bottomNavigationBar: SafeArea(
          child: ValueListenableBuilder(
            valueListenable: _selectedIndex,
            builder: (BuildContext context, int indexValue, Widget? child) {
              return AnimatedContainer(
                duration: const Duration(milliseconds: 100),
                height: 60,
                child: SalomonBottomBar(
                  currentIndex: indexValue,
                  onTap: (index) {
                    _onItemTapped(index);
                  },
                  items: [
                    /// Home
                    SalomonBottomBarItem(
                      icon: const Icon(Icons.home_rounded),
                      title: Text(AppLocalizations.of(context)!.home),
                      selectedColor: Theme.of(context).colorScheme.secondary,
                    ),

                    SalomonBottomBarItem(
                      icon: const Icon(Icons.trending_up_rounded),
                      title: Text(AppLocalizations.of(context)!.spotifyCharts),
                      selectedColor: Theme.of(context).colorScheme.secondary,
                    ),
                    SalomonBottomBarItem(
                      icon: const Icon(MdiIcons.youtube),
                      title: Text(AppLocalizations.of(context)!.youTube),
                      selectedColor: Theme.of(context).colorScheme.secondary,
                    ),
                    SalomonBottomBarItem(
                      icon: const Icon(Icons.my_library_music_rounded),
                      title: Text(AppLocalizations.of(context)!.library),
                      selectedColor: Theme.of(context).colorScheme.secondary,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
