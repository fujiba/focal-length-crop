# Focal Length Crop

> 目標焦点距離を指定するだけで、Lightroom Classicのクロップ矩形を自動計算するプラグイン。

「この構図、もし1000mmで撮ってたらどう写るやろ？」
そんなレンズ選びシミュレーションや、複数機材の画角比較に使える、航空写真作家向けのちょいニッチプラグイン。

## 特徴

- **目標焦点距離を入力するだけ** で、現像設定のクロップ矩形を自動計算
- **APS-C / フルサイズ自動判定**：EXIFの35mm換算値からクロップファクターを自動算出
- **既存クロップの中心・アスペクト比を維持**：途中まで構図決めた状態からの引き寄せに使える
- **35mm換算値をリアルタイム表示**：入力中に「これ換算何mm？」が見える

## 動作要件

- Adobe Lightroom Classic（バージョン 6 / CC 2015 以降）
- ※新しいクラウド版Lightroom（モバイル系）はプラグイン非対応のため利用不可

## インストール

### 方法1：手動インストール（推奨）

1. [Releases](https://github.com/fujiba/focal-length-crop/releases) から最新の `FocalLengthCrop-vX.Y.Z.zip` をダウンロード
2. 解凍して出てきた `FocalLengthCrop.lrplugin` フォルダを好きな場所に配置
   - macOS推奨パス: `~/Library/Application Support/Adobe/Lightroom/Modules/`
   - Windows推奨パス: `%APPDATA%\Adobe\Lightroom\Modules\`
3. Lightroom Classicを起動
4. **ファイル → プラグインマネージャー → 追加** で `FocalLengthCrop.lrplugin` を選択

### 方法2：Gitクローン（開発者向け）

```bash
git clone https://github.com/fujiba/focal-length-crop.git
```

その後Lightroomのプラグインマネージャでクローンしたディレクトリ内の `FocalLengthCrop.lrplugin` を追加。

## 使い方

1. クロップしたい写真を**ライブラリモジュール**で選択（現像モジュールでも可、ただしメニューはライブラリ側）
2. メニューから **ファイル → プラグインエクストラ → 焦点距離指定でクロップ...**
3. ダイアログに撮影情報が表示される：
   - カメラモデル
   - 実焦点距離（EXIFから自動取得）
   - クロップファクター（×1.5など、APS-Cなら自動算出）
4. **目標焦点距離（実レンズ基準）** を入力（例: 800）
   - 入力中に「35mm換算 ○○mm 相当」がリアルタイム表示される
5. **OK** を押すと現像設定にクロップが適用される

### 使用例

| 撮影機材                 | 実焦点距離 | 目標焦点距離 | 結果                                     |
| ------------------------ | ---------- | ------------ | ---------------------------------------- |
| K-1 Mark II + DFA★70-200 | 200mm      | 300mm        | 0.67倍にトリミング（35mm換算 200→300mm） |
| K-3 Mark III + DA★60-250 | 250mm      | 560mm        | 0.45倍にトリミング（35mm換算 375→840mm） |
| K-3 Mark III + 望遠      | 450mm      | 600mm        | 0.75倍にトリミング                       |

## 設計上の注意点

- **「目標焦点距離」は実レンズ焦点距離として指定**します（同じカメラボディに別のレンズを付ける想定）
- 目標焦点距離は実焦点距離以上である必要があります（クロップでは広角化はできない）
- クロップ中心は既存クロップの中心を維持しますが、画像端からはみ出す場合は内側にシフトします
- 適用後はLightroomのUndo（Ctrl/Cmd + Z）で戻せます

## 既知の制約

- Lightroom SDKの`applyDevelopSettings`APIは公式にはexperimental扱いです。長年使われていますが、将来のLightroomアップデートで動作が変わる可能性があります
- バッチ処理（複数写真への一括適用）は現バージョン未対応
- 回転・水平補正（CropAngle）が適用済みの写真でも動作しますが、角度を考慮した最適化は行いません

## ライセンス

MIT License - [LICENSE](LICENSE) を参照

## 作者

**ふじば (FUJIBA WORKS)**

- 航空写真作家・プログラマ
- Web: https://fujiba.net/

## 変更履歴

[CHANGELOG.md](CHANGELOG.md) を参照
