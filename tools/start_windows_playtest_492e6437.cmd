@echo off
setlocal EnableExtensions DisableDelayedExpansion
set "playtest_version=492e6437"
set "playtest_depot=%~dp0SteamDepot"
if not exist "%playtest_depot%\LiangshanHeroes.exe" set "playtest_depot=%~dp0."
for %%F in (LiangshanHeroes.exe libgodotsteam.windows.template_release.x86_64.dll steam_api64.dll steam_stats_reader.dll GODOTSTEAM_LICENSE.txt STEAM_STATS_READER_GODOT_CPP_LICENSE.txt) do (
    if not exist "%playtest_depot%\%%F" (
        echo Missing %%F. Extract all six game files first.
        exit /b 2
    )
)

set "playtest_player=QA"
if /i "%~1"=="--check" goto profile
choice /C 123 /N /M "Choose your player number: 1 = P01, 2 = P02, 3 = P03 "
if errorlevel 4 exit /b 2
if errorlevel 3 goto player3
if errorlevel 2 goto player2
if errorlevel 1 goto player1
exit /b 2

:player3
set "playtest_player=P03"
goto profile
:player2
set "playtest_player=P02"
goto profile
:player1
set "playtest_player=P01"

:profile
if not defined LOCALAPPDATA exit /b 2
set "playtest_root=%LOCALAPPDATA%\LiangshanHeroesPlaytest\%playtest_version%\%playtest_player%"
for %%D in (appdata localappdata temp tmp xdg_data_home xdg_config_home) do (
    if not exist "%playtest_root%\%%D\" mkdir "%playtest_root%\%%D"
    if not exist "%playtest_root%\%%D\" exit /b 2
)
set "APPDATA=%playtest_root%\appdata"
set "LOCALAPPDATA=%playtest_root%\localappdata"
set "TEMP=%playtest_root%\temp"
set "TMP=%playtest_root%\tmp"
set "XDG_DATA_HOME=%playtest_root%\xdg_data_home"
set "XDG_CONFIG_HOME=%playtest_root%\xdg_config_home"
for %%E in (LEVEL SKIRMISH SKIRMISH_AI ARENA SCENARIO CUSTOM_DEFENSE SCREENSHOT_DIR SMOKE_TEST CAMPAIGN_QA AUTO_MICRO AUTOMICRO AI_FRIENDLY AI_FRIENDLY_MULT AI_DIFF SCALE_ON ENEMY_MULT HERO_MULT VICTORY DEF_WAVES DEF_HEROES DEF_RANDOM DEF_INTERVAL NEWHERO PROF PERF_BENCH TOUCH_UI LSH_CONTINUE_FLOW_QA LSH_CONTINUE_FLOW_PROFILE) do set "%%E="
set "STEAM_DISABLED=1"
set "CONTENT_UPDATE_NO_AUTO=1"

pushd "%playtest_depot%" || exit /b 2
if /i "%~1"=="--check" goto verify
echo Starting the offline playtest for %playtest_player%...
LiangshanHeroes.exe
goto done

:verify
LiangshanHeroes.exe --headless --max-fps 60 --quit-after 900 --log-file "%playtest_root%\launcher-check.log"

:done
set "playtest_exit=%errorlevel%"
popd
exit /b %playtest_exit%
