#import "Basic";
#import "thegame_math";

SHARED_FOLDER_NAME :: "shared";
#if OS == .WINDOWS {
//TODO Should this be win_thegame?
EXE_NAME :: "windows_thegame";
} else #if OS == .MACOS {
EXE_NAME :: "macos_thegame";
}
BUILD_DL_NAME :: "build_dl_thegame.jai";
FILES_DIR_NAME :: "guides";
RESOURCES_DIR_NAME :: "resources";
C_LOAD_DIR_NAME :: "c_load";
C_TEST_DIR_NAME :: "c_test";
SETTINGS_DIR_NAME :: "settings";
TEST_SETTINGS_DIR_NAME :: "test_settings";
CODE_DLS_DIR_NAME :: "code_dls";
G_STARTUP_SETTINGS_NAME :: #run sprint("%/generated_startup_settings", SETTINGS_DIR_NAME);
G_RUNTIME_SETTINGS_NAME :: #run sprint("%/generated_runtime_settings", SETTINGS_DIR_NAME);
G_INPUT_MAPPINGS_NAME :: #run sprint("%/generated_input_mappings", SETTINGS_DIR_NAME);

WHITE_V :: Vector4F.{1.0, 1.0, 1.0, 1.0};
BLACK_V :: Vector4F.{0.0, 0.0, 0.0, 1.0};
LOW_WHITE_V :: Vector4F.{0.95, 0.95, 0.95, 1.0};
LOW2_WHITE_V :: Vector4F.{0.85, 0.85, 0.85, 1.0};
LOWER_WHITE_V :: Vector4F.{0.8, 0.8, 0.8, 1.0};
GREY_DARK_V :: Vector4F.{194.0/255.0, 192.0/255.0, 188.0/255.0, 1.0};
GREY_DARKERM_V :: Vector4F.{137.0/255.0, 135.0/255.0, 133.0/255.0, 1.0};
GREY_DARKERM2_V :: Vector4F.{114.0/255.0, 112.0/255.0, 110.0/255.0, 1.0};
GREY_DARKER_V :: Vector4F.{84.0/255.0, 82.0/255.0, 78.0/255.0, 1.0};
GREY_DARKEST_V :: Vector4F.{62.0/255.0, 62.0/255.0, 62.0/255.0, 1.0};
GREY_DARKEST2_V :: Vector4F.{36.0/255.0, 36.0/255.0, 36.0/255.0, 1.0};
GREY_BLACK_V :: Vector4F.{48.0/255.0, 48.0/255.0, 48.0/255.0, 1.0};
GREY_BLACKER_V :: Vector4F.{24.0/255.0, 24.0/255.0, 24.0/255.0, 1.0};
GREY_V :: Vector4F.{219.0/255.0, 217.0/255.0, 215.0/255.0, 1.0};
GREEN_V :: Vector4F.{0, 1.0, 0, 1.0};
LIGHT_BROWN :: Vector4F.{176.0/255.0, 159.0/255.0, 125.0/255.0, 1.0};
LIGHTER_BROWN :: Vector4F.{201.0/255.0, 177.0/255.0, 138.0/255.0, 1.0};
TEXT_BROWN :: Vector4F.{201.0/255.0, 177.0/255.0, 138.0/255.0, 1.0};
DARK_BROWN :: Vector4F.{78.0/255.0, 53.0/255.0, 36.0/255.0, 1.0};
BLUE_V :: Vector4F.{0, 0, 1.0, 1.0};
FGREEN_V :: Vector4F.{143.0/255.0, 210.0/255.0, 121.0/255.0, 1.0};
RED_V :: Vector4F.{255.0/255.0, 30.0/255.0, 90.0/255.0, 1.0};
LRED_V := Vector4F.{125.0/255.0, 15.0/255.0, 45.0/255.0, 1.0};
MRED_V :: Vector4F.{230.0/255.0, 108.0/255.0, 70/255.0, 1.0};

//blues
LBLUE_V :: Vector4F.{0/255.0, 175.0/255.0, 255.0/255.0, 1.0};
DBLUE_V :: Vector4F.{0/255.0, 0.3*175.0/255.0, 0.3*255.0/255.0, 1.0};
MBLUE_V :: Vector4F.{0/255.0, 0.45*175.0/255.0, 0.45*255.0/255.0, 1.0};
// LMBLUE_V :: #run (0.65 * LBLUE_V); //can do this since we also multiply the alpha by 0.65
//LMBLUE_V and DBLUE_V are very similar but the alpha of LMBLUE_V feels a bit less harsh but changes with other colors
//TODO SETTING SO these will be user settable since background and font color will be settable as well
LMBLUE_V :: #run (0.53 * LBLUE_V); //can do this since we also multiply the alpha by 0.65
// LMBLUE_V :: Vector4F.{0/255.0, 0.65*175.0/255.0, 0.65*255.0/255.0, 0.55};

ORANGE_V :: Vector4F.{1.0, 204.0/255.0, 102.0/255.0, 1.0};
GREENC_V :: Vector4F.{73.0/255.0, 143.0/255.0, 51.0/255.0, 1.0};
YELLOW_V :: Vector4F.{245.0/255.0, 245.0/255.0, 50.0/255.0, 1.0};
PINK_V := Vector4F.{255.0/255.0, 111.0/255.0, 255/255.0, 1.0};