--[[----------------------------------------------------------------------------
FocalLengthCrop.lua  (v0.2)

仕様:
  - 「目標焦点距離」は実レンズ焦点距離として指定（同じカメラに別レンズを付けた想定）
  - クロップファクターはEXIFから自動算出（FocalLengthIn35mmFilm / FocalLength）
  - クロップ中心 = 既存クロップの中心を維持
  - アスペクト比 = 既存クロップの比を維持
  - ダイアログにクロップファクター・35mm換算値・スケール率を表示

数学的補足:
  目標焦点距離を「実レンズ基準」で受け取る場合、スケール率は
    scale = realFocal / targetFocal
  でOK。APS-Cもフルサイズも同じ式。
  (同じボディに装着するレンズ前提だから、センサーサイズ係数は両辺でキャンセルされる)
------------------------------------------------------------------------------]]

local LrApplication      = import "LrApplication"
local LrDialogs          = import "LrDialogs"
local LrFunctionContext  = import "LrFunctionContext"
local LrTasks            = import "LrTasks"
local LrView             = import "LrView"
local LrBinding          = import "LrBinding"
local LrLogger           = import "LrLogger"

local logger = LrLogger("FocalLengthCrop")
logger:enable("print")

--------------------------------------------------------------------------------
-- ユーティリティ
--------------------------------------------------------------------------------

--- EXIFのfocalLength文字列から数値を抽出
-- 例: "560 mm" -> 560, "70.5 mm" -> 70.5
local function parseFocalLength(str)
    if not str then return nil end
    local num = str:match("([%d%.]+)")
    return num and tonumber(num) or nil
end

--- 現在の現像設定からクロップ矩形を取得
-- 戻り値: { left, top, right, bottom }（0.0〜1.0正規化座標）
local function getCurrentCrop(developSettings)
    return {
        left   = developSettings.CropLeft   or 0,
        top    = developSettings.CropTop    or 0,
        right  = developSettings.CropRight  or 1,
        bottom = developSettings.CropBottom or 1,
    }
end

--- 既存クロップの中心とアスペクト比を維持して、scale倍に縮小したクロップを計算
local function calculateNewCrop(currentCrop, scale)
    local centerX = (currentCrop.left + currentCrop.right)  / 2
    local centerY = (currentCrop.top  + currentCrop.bottom) / 2

    local width  = currentCrop.right  - currentCrop.left
    local height = currentCrop.bottom - currentCrop.top

    local currentMax = math.max(width, height)
    local relativeScale = scale / (currentMax > 0 and currentMax or 1)
    local newWidth  = width  * relativeScale
    local newHeight = height * relativeScale

    local newLeft   = centerX - newWidth  / 2
    local newRight  = centerX + newWidth  / 2
    local newTop    = centerY - newHeight / 2
    local newBottom = centerY + newHeight / 2

    -- 画像範囲(0〜1)に収まるよう、はみ出す場合はクロップ全体を内側にシフト
    if newLeft < 0 then
        newRight = newRight - newLeft
        newLeft  = 0
    end
    if newRight > 1 then
        newLeft  = newLeft - (newRight - 1)
        newRight = 1
    end
    if newTop < 0 then
        newBottom = newBottom - newTop
        newTop    = 0
    end
    if newBottom > 1 then
        newTop    = newTop - (newBottom - 1)
        newBottom = 1
    end

    return {
        CropLeft   = newLeft,
        CropTop    = newTop,
        CropRight  = newRight,
        CropBottom = newBottom,
    }
end

--------------------------------------------------------------------------------
-- ダイアログUI
--------------------------------------------------------------------------------

--- 目標焦点距離入力ダイアログ
-- @param info.realFocal     実焦点距離(mm)
-- @param info.equiv35Focal  35mm換算焦点距離(mm, EXIFから取得 or nil)
-- @param info.cropFactor    クロップファクター(equiv35/real, nil可)
-- @param info.cameraModel   カメラモデル名(表示用)
-- @return 目標焦点距離(mm) or nil(キャンセル)
local function showFocalLengthDialog(info)
    return LrFunctionContext.callWithContext("focalLengthDialog", function(context)
        local f = LrView.osFactory()
        local props = LrBinding.makePropertyTable(context)
        props.targetFocal = info.realFocal -- 初期値=実焦点距離

        -- 換算焦点距離の動的計算（プレビュー用）
        props.targetEquiv35 = info.cropFactor
            and (info.realFocal * info.cropFactor) -- 初期値（換算）
            or info.realFocal

        -- targetFocalが変わったらtargetEquiv35も再計算
        props:addObserver("targetFocal", function()
            if info.cropFactor and props.targetFocal then
                props.targetEquiv35 = props.targetFocal * info.cropFactor
            end
        end)

        -- ノトリーティネーエスト：現状情報の表示文字列を組み立て
        local cameraInfoLine = info.cameraModel
            and string.format("カメラ: %s", info.cameraModel)
            or "カメラ: (不明)"

        local realFocalLine = string.format("実焦点距離: %g mm", info.realFocal)

        local cropFactorLine
        if info.cropFactor and info.equiv35Focal then
            cropFactorLine = string.format(
                "クロップファクター: ×%.2f (35mm換算 %g mm)",
                info.cropFactor, info.equiv35Focal
            )
        else
            cropFactorLine = "クロップファクター: (EXIFに35mm換算値なし、×1.0として扱います)"
        end

        local contents = f:column {
            bind_to_object = props,
            spacing = f:control_spacing(),

            -- ===== 現状情報セクション =====
            f:group_box {
                title = "撮影情報",
                fill_horizontal = 1,

                f:static_text { title = cameraInfoLine },
                f:static_text { title = realFocalLine },
                f:static_text { title = cropFactorLine },
            },

            -- ===== 入力セクション =====
            f:group_box {
                title = "目標焦点距離（実レンズ基準）",
                fill_horizontal = 1,

                f:row {
                    f:edit_field {
                        value     = LrView.bind("targetFocal"),
                        min       = info.realFocal,
                        max       = 10000,
                        precision = 1,
                        width_in_chars = 8,
                        immediate = true,
                    },
                    f:static_text { title = "mm" },

                    f:spacer { width = 20 },

                    f:static_text {
                        title = LrView.bind {
                            key = "targetEquiv35",
                            transform = function(value)
                                if info.cropFactor then
                                    return string.format("(35mm換算 %.0f mm 相当)", value)
                                else
                                    return ""
                                end
                            end,
                        },
                        text_color = LrView.kColorDisabled,
                    },
                },
            },

            f:static_text {
                title = "※ 目標焦点距離は実焦点距離以上を指定してください\n   (短い焦点距離=広角化はクロップでは不可能)",
                text_color = LrView.kColorDisabled,
            },
        }

        local result = LrDialogs.presentModalDialog {
            title    = "焦点距離指定クロップ",
            contents = contents,
        }

        if result == "ok" then
            return props.targetFocal
        else
            return nil
        end
    end)
end

--------------------------------------------------------------------------------
-- メイン処理
--------------------------------------------------------------------------------

LrTasks.startAsyncTask(function()
    local catalog = LrApplication.activeCatalog()
    local photo   = catalog:getTargetPhoto()

    if not photo then
        LrDialogs.message(
            "写真が選択されていません",
            "クロップ対象の写真を選択してください。",
            "warning"
        )
        return
    end

    -- ===== EXIF取得 =====
    local realFocal    = photo:getRawMetadata("focalLength")
    local equiv35Focal = photo:getRawMetadata("focalLength35mm")
    local cameraModel  = photo:getFormattedMetadata("cameraModel")

    if not realFocal or realFocal <= 0 then
        LrDialogs.message(
            "焦点距離が取得できません",
            "この写真のEXIFに焦点距離情報が含まれていません。",
            "warning"
        )
        return
    end

    -- クロップファクター算出（EXIFに35mm換算値がある場合のみ）
    local cropFactor = nil
    if equiv35Focal and equiv35Focal > 0 then
        cropFactor = equiv35Focal / realFocal
    end

    logger:trace(string.format(
        "[Info] camera=%s, real=%g mm, equiv35=%s mm, cropFactor=%s",
        tostring(cameraModel),
        realFocal,
        tostring(equiv35Focal),
        cropFactor and string.format("%.3f", cropFactor) or "nil"
    ))

    -- ===== ダイアログ =====
    local targetFocal = showFocalLengthDialog {
        realFocal    = realFocal,
        equiv35Focal = equiv35Focal,
        cropFactor   = cropFactor,
        cameraModel  = cameraModel,
    }

    if not targetFocal then
        return -- キャンセル
    end

    if targetFocal < realFocal then
        LrDialogs.message(
            "無効な値です",
            "目標焦点距離は実焦点距離以上である必要があります。",
            "warning"
        )
        return
    end

    -- ===== スケール率計算 =====
    -- 実レンズ基準なので、シンプルに realFocal / targetFocal でOK
    -- (APS-Cもフルサイズも、同じボディに装着する想定だから補正不要)
    local scale = realFocal / targetFocal

    logger:trace(string.format(
        "[Calc] scale=%.4f (= %g / %g)",
        scale, realFocal, targetFocal
    ))

    -- ===== 現在のクロップ取得 =====
    local developSettings = photo:getDevelopSettings()
    local currentCrop     = getCurrentCrop(developSettings)

    logger:trace(string.format(
        "[Before] crop=(L=%.4f T=%.4f R=%.4f B=%.4f)",
        currentCrop.left, currentCrop.top, currentCrop.right, currentCrop.bottom
    ))

    -- ===== 新クロップ計算 =====
    local newCrop = calculateNewCrop(currentCrop, scale)

    logger:trace(string.format(
        "[After]  crop=(L=%.4f T=%.4f R=%.4f B=%.4f)",
        newCrop.CropLeft, newCrop.CropTop, newCrop.CropRight, newCrop.CropBottom
    ))

    -- ===== 適用 =====
    catalog:withWriteAccessDo("Apply Focal Length Crop", function()
        photo:applyDevelopSettings(newCrop)
    end)

    -- ===== 完了通知（Bezel = 画面下部の一時表示） =====
    local bezelMsg
    if cropFactor then
        bezelMsg = string.format(
            "%g mm → %g mm 相当 (35mm換算: %g → %.0f mm)",
            realFocal, targetFocal,
            equiv35Focal, targetFocal * cropFactor
        )
    else
        bezelMsg = string.format(
            "%g mm → %g mm 相当 (×%.2f トリミング)",
            realFocal, targetFocal, targetFocal / realFocal
        )
    end
    LrDialogs.showBezel(bezelMsg)
end)
