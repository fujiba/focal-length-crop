--[[----------------------------------------------------------------------------
Focal Length Crop - Lightroom Classic Plugin
焦点距離を指定してクロップ矩形を計算するプラグイン

@author  fujiba (FUJIBA WORKS)
@license MIT
------------------------------------------------------------------------------]]

return {
    LrSdkVersion          = 10.0,
    LrSdkMinimumVersion   = 6.0,
    LrToolkitIdentifier   = "net.fujiba.lightroom.focallength-crop",
    LrPluginName          = "Focal Length Crop",
    LrPluginInfoUrl       = "https://www.fujiba.net/",

    LrLibraryMenuItems = {
        {
            title = "焦点距離指定でクロップ...",
            file  = "FocalLengthCrop.lua",
        },
    },

    LrExportMenuItems = {
        {
            title = "焦点距離指定でクロップ...",
            file  = "FocalLengthCrop.lua",
        },
    },

    VERSION = { major = 0, minor = 2, revision = 0, build = 1 },
}
