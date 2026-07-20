# プチコン(SmileBASIC)からGodot 4への縦スクロールSTG移植・開発指示書

このドキュメントは、プチコン4（SmileBASIC）で開発された縦スクロールシューティングゲーム（STG）のモックアップソースコードおよび実機動作キャプチャをもとに、Godot 4（GDScript 2.0）への移植およびクオリティアップを行うための設計考察と、AIエージェントへの指示用プロンプトをまとめたものです。

---

## 1. オリジナル（プチコン版）のシステム分析と特徴

提供されたソースコードおよび動作動画から、以下の重要なコア仕様が特定されています。

1. **8方向移動と斜め移動補正:**
   - 入力を正規化し、斜め移動時に自機の移動速度が $\sqrt{2}$ 倍（約1.414倍）にならないよう手動で減速補正。
2. **グラディウス型トレイルバッファによるオプション（子機）追従:**
   - 自機の過去の座標履歴を固定長配列（リングバッファ：`MOD #PDIM`）に毎フレーム記録。
   - 左右のオプション（`OptionLeft`, `OptionRight`）が、指定したフレーム数（ディレイ時間）だけ過去の座標をベースにした相対位置に追従する。
   - **【最重要ゲームフィール】** 移動速度に応じてオプションとの距離がゴムのように伸び縮みし、自機停止時には手元に引き戻されるような弾性・しなやかさを持つ。これが「触って気持ちいい手触り」の核である。
3. **自機とオプションを繋ぐレーザー演出:**
   - メインループ内で `GLINE` を用いて、自機と左右のオプションの間にリアルタイムで赤いラインを描画。
4. **スプライトと当たり判定の管理:**
   - 各スプライト（弾、敵、背景など）の領域を定数で管理し、`SPHITSP` で衝突判定。敵には耐久力（`LIFE`）があり、0になるとアニメーション（`SPANIM`）を伴う爆発（`EXPLOD01/02`）が発生し消滅。
5. **三角関数テーブル:**
   - 高速化のため、起動時に `SINTBL`/`COSTBL` を作成し、3WAY弾などのベクトル計算（`ATAN`/`COS`/`SIN`）に使用。

---

## 2. Godot 4への移植方針・改良考察

### ① ゲーム構造の最適化（2.5Dスタイル）
- **ゲームロジック（自機・敵・弾・判定）:** すべて扱いやすく数学的狂いの生じない**2D（`Node2D`系）**で実装。
- **背景:** 裏で `SubViewport` を回し、その中で3D空間のカメラをゆっくり奥にスクロールさせることで、**「美麗な3D背景の上を、完全に制御された2D自機が飛び回る」**リッチな2.5D画面を実現。

### ② リングバッファから「キュー（Queue）構造」への洗練
- プチコンのインデックス制御（`MOD`）から、GDScriptの高速な配列操作メソッド（`push_front()` / `pop_back()`）によるキュー構造へ移行。
- メモリ効率を維持しつつ、バグを排除し、コードの可読性を大幅に向上させる。

### ③ 「ゴムのような追従感」の維持と極大化
- プチコンが持つ「速度で伸縮する時間差ディレイ」の気持ちよさを完全に再現するため、まずは純粋なフレーム遅延型のバッファを採用する。
- さらに、Godotのインスペクターでリアルタイムに硬さを調整できるよう、**バネ物理（スプリング・ダンパー）モデル**への拡張性を持たせた設計とする。

### ④ グラフィックと演出の現代化
- `GLINE` による赤い線は、Godot 4の `CanvasItem._draw()` で描画しつつ、ワールド環境に **Glow（発光）エフェクト** をかけることで、暗い宇宙背景にネオンのように美しく輝くレーザーへと進化させる。

---

## 3. AIエージェント（Gemini/Claude CLI）への開発指示用プロンプト

AIエージェントにプロジェクト作成と最初のコアロジックを実装させるためのプロンプトテンプレートです。そのままCLIに投入できます。

### 📋 プロンプト 1：プロジェクトの骨組みとプレイヤーの基本移動
> **指示：**
> Godot 4 (GDScript 2.0) で動作する、2Dの縦スクロールシューティングゲームのプレイヤーノード（`CharacterBody2D`）用のスクリプトを作成してください。
>
> **要件：**
> 1. `Input.get_vector()` を使用して8方向移動を滑らかに実装してください（斜め移動の正規化は自動で行うこと）。
> 2. プレイヤーが画面外に出ないよう、`get_viewport_rect().size` を用いて位置を適切にクランプ（制限）してください。
> 3. スペースキー（アクション名: `"shoot"`）が押されたら、後述する弾のシーン（`bullet_scene`）をインスタンス化して発射する `shoot()` 関数を作ってください。弾はプレイヤーの子ノードではなく、ゲームのメインツリー（親ノードなど）に追加してください。

### 📋 プロンプト 2：【核心】ゴム感を持つトレイルオプションとレーザー線の描画
> **指示：**
> 先ほど作成したプレイヤースクリプトに、プチコン版の仕様である「時間差追従オプション」と「自機と結ぶレーザー線」のロジックを統合・拡張してください。
>
> **要件：**
> 1. 配列 `position_history: Array[Vector2]` を用意し、毎フレーム自機の `global_position` を先頭に追加（`push_front`）、一定上限を超えたら末尾を削除（`pop_back`）するキュー構造を作ってください。
> 2. プレイヤーの子ノードとして存在する左右のオプション（`OptionLeft`, `OptionRight`）を、バッファ内の指定した過去のフレーム数（例: 15フレーム前）の座標ベースで追従させてください。自機からのオフセット（X: 22, Y: 12）を持たせてください。
> 3. 移動速度に応じて距離が伸び縮みする「ゴムのような伸縮感」を完全に再現してください。
> 4. `_draw()` 関数をオーバーライドし、自機の中心から左右のオプションのグローバル座標を結ぶ、太さ2.0pxの赤いライン（`Color.RED`）をリアルタイムに描画してください。毎フレーム `queue_redraw()` を呼ぶことを忘れないでください。


------ org source code (putit-com basic)

'======================================================================
' 縦スクロールシューティングゲーム モックアップソースコード
'======================================================================

'----------------------------------------------------------------------
' 1. 定数・グローバル変数宣言と初期化
'----------------------------------------------------------------------
' ゲーム実行ステート定義
CONST #GS_TITLE = 0
CONST #GS_END = 1
CONST #GS_PLAY = 2
VAR _GAMESTATE = #GS_PLAY

' 画面範囲定義
CONST #SCR_X1 = 0
CONST #SCR_Y1 = 0
CONST #SCR_X2 = 400
CONST #SCR_Y2 = 240
CONST #C_CLEAR = 0

' 汎用変数
VAR I, J, K, SX, SY, SP
VAR EX, EY, VX, VY, TMP, TMPX, TMPY, RET

' プレイヤー関連変数
VAR PLX = 200, PLY = 200 ' プレイヤー初期座標
VAR ORX, ORY, OLX, OLY    ' オプション（右・左）の座標
VAR MSHTTMR = 0, MSHTFLG = 0
VAR OSHTTMR = 0, OSHTFLG = 0

' プレイヤー軌跡用配列（トレイルバッファ）
CONST #PDIM = 120
VAR PXD[#PDIM], PYD[#PDIM]
VAR PD_PTR = 0
VAR OPTP = 0

' オプションのオフセット座標と角度
CONST #OPTOFSX = 22
CONST #OPTOFSY = 12
DIM OPTANGR[9] = [0, 15, 30, 45, 60, 75, 90, 105, 120]
DIM OPTANGL[9] = [0, -15, -30, -45, -60, -75, -90, -105, -120]
VAR OPTANGMAX = 9
VAR OPTANGPOS = 0
VAR OPTLOCK = #FALSE

' スプライト管理用定数（領域定義）
CONST #SP_PL = 0       ' 自機
CONST #SP_OPR = 1      ' オプション右
CONST #SP_OPL = 2      ' オプション左
CONST #SP_BLT01_S = 10 ' 自機通常弾開始
CONST #SP_BLT01_E = 30 ' 自機通常弾終了
CONST #SP_BLT02_S = 31 ' オプション弾開始
CONST #SP_BLT02_E = 50 ' オプション弾終了
CONST #SP_ENMY_S = 100 ' 敵開始
CONST #SP_ENMY_E = 150 ' 敵終了
CONST #SP_BGGRID_S = 200
CONST #SP_BGGRID_E = 300

' スプライトグラフィック定義番号 (SPDEF用)
CONST #DSP_PL = 0
CONST #DSP_OP = 1
CONST #DSP_BLT01 = 2
CONST #DSP_BLT02 = 3
CONST #DSP_EN01 = 4
CONST #DSP_EXP01 = 5
CONST #ELIFE = 0       ' SPVAR用：敵ライフのインデックス

' 配列初期化（自機軌跡バッファを初期位置で埋める）
FOR I = 0 TO #PDIM - 1
  PXD[I] = PLX
  PYD[I] = PLY
NEXT

' SIN/COS 高速化テーブル作成
DIM SINTBL[360], COSTBL[360]
FOR I = 0 TO 359
  SINTBL[I] = SIN(RAD(I))
  COSTBL[I] = COS(RAD(I))
NEXT

'----------------------------------------------------------------------
' 2. メインループ
'----------------------------------------------------------------------
@GS_PLAY
LOOP
  ' スティック入力取得と補正
  STICK 0 OUT SX, SY
  SX = SX * 2: SY = SY * 2
  SX = SGN(ROUND(SX)): SY = SGN(ROUND(SY))

  ' オプションの角度固定（R1ボタンでロック）
  OPTLOCK = #FALSE
  IF BUTTON(0, #B_R1) == 1 THEN OPTLOCK = #TRUE

  ' 斜め移動速度の補正（1.414で除算）
  IF SX != 0 && SY != 0 THEN
    SX = SX / 1.414
    SY = SY / 1.414
  ENDIF

  ' 自機座標更新と移動速度調整
  PLX = PLX + SX * 3
  PLY = PLY + SY * 3

  ' 画面外はみ出しチェック処理
  IF PLX < #SCR_X1 + 16 THEN PLX = #SCR_X1 + 16
  IF PLX > #SCR_X2 - 16 THEN PLX = #SCR_X2 - 16
  IF PLY < #SCR_Y1 + 16 THEN PLY = #SCR_Y1 + 16
  IF PLY > #SCR_Y2 - 16 THEN PLY = #SCR_Y2 - 16

  ' 自機の表示更新
  SPOFS #SP_PL, PLX, PLY

  ' 軌跡バッファの保存
  PXD[PD_PTR] = PLX
  PYD[PD_PTR] = PLY
  PD_PTR = (PD_PTR + 1) MOD #PDIM

  ' オプションの角度変更ロジック
  IF !OPTLOCK THEN
    ' 入力や状況に応じて OPTANGPOS を増減させる処理（任意調整）
  ENDIF

  ' オプションの追従移動（ポインタを15フレーム遅らせる）
  OPTP = (PD_PTR + #PDIM - 15) MOD #PDIM
  ORX = PXD[OPTP] + #OPTOFSX
  ORY = PYD[OPTP] + #OPTOFSY
  OLX = PXD[OPTP] - #OPTOFSX
  OLY = PYD[OPTP] + #OPTOFSY

  ' オプションのスプライト座標と回転適用
  SPOFS #SP_OPR, ORX, ORY: SPROT #SP_OPR, OPTANGR[OPTANGPOS]
  SPOFS #SP_OPL, OLX, OLY: SPROT #SP_OPL, OPTANGL[OPTANGPOS]

  ' 自機とオプションを結ぶレーザーの描画（画面クリアと線引き）
  GFILL #SCR_X1, #SCR_Y1, #SCR_X2, #SCR_Y2, #C_CLEAR
  GLINE PLX, PLY, ORX, ORY, RGB(255, 0, 0)
  GLINE PLX, PLY, OLX, OLY, RGB(255, 0, 0)

  ' 各種オブジェクト（弾・敵）の移動処理呼び出し
  GOSUB @MVBLT01
  GOSUB @MVOPTBLT
  GOSUB @MVENBLT

  ' ショット発射処理
  IF BUTTON(0, #B_LABYN) == 1 THEN ' ボタン押下時
    SHOTBLT01 PLX, PLY
  ENDIF

  VSYNC
ENDLOOP

'----------------------------------------------------------------------
' 3. 移動・更新用サブルーチン
'----------------------------------------------------------------------
' 自機通常弾の移動処理
@MVBLT01
FOR SP = #SP_BLT01_S TO #SP_BLT01_E
  IF SPUSED(SP) == 1 THEN
    SPOFS SP OUT TMPX, TMPY
    TMPY = TMPY - 6 ' 上へ移動
    
    ' 敵との当たり判定
    COL_ENEMY SP OUT TMP
    IF TMP == #FALSE THEN
      ' 敵に当たっていなければ背景判定と画面外消去
      COL_BG SP OUT TMP
      IF TMP == #TRUE THEN
        SPCLR SP
      ELSE
        IF OUTFSCRN(TMPX, TMPY) THEN
          SPCLR SP
        ELSE
          SPOFS SP, TMPX, TMPY
        ENDIF
      ENDIF
    ENDIF
  ENDIF
NEXT
RETURN

' オプション弾の移動処理
@MVOPTBLT
FOR SP = #SP_BLT02_S TO #SP_BLT02_E
  IF SPUSED(SP) == 1 THEN
    SPOFS SP OUT TMPX, TMPY
    ' 弾ごとに設定されたベクトル(SPVAR等)で移動させる処理
    ' （中略）
    COL_ENEMY SP OUT TMP
    IF TMP == #FALSE THEN
      COL_BG SP OUT TMP
      IF OUTFSCRN(TMPX, TMPY) THEN SPCLR SP
    ENDIF
  ENDIF
NEXT
RETURN

' 敵の移動処理
@MVENBLT
' 敵スプライトの巡回と挙動処理
RETURN

'----------------------------------------------------------------------
' 4. ユーザー定義関数 (DEF)
'----------------------------------------------------------------------
' 自機通常弾の発射
DEF SHOTBLT01 _PX, _PY
  VAR _SP = -1
  ' 空いているスプライトを探してセット
  FOR I = #SP_BLT01_S TO #SP_BLT01_E
    IF SPUSED(I) == 0 THEN _SP = I: BREAK
  NEXT
  IF _SP == -1 THEN RETURN
  
  SPSET _SP, #DSP_BLT01
  SPOFS _SP, _PX, _PY - 8
  BEEP 145 ' 発射音
END

' 2点間のベクトル計算 (AからBへの移動量)
DEF GETVEC_A2B _AX, _AY, _BX, _BY OUT _VX, _VY
  VAR _ANG = ATAN(_BY - _AY, _BX - _AX)
  _VX = COS(_ANG)
  _VY = SIN(_ANG)
END

' 3WAY弾用ベクトル計算
DEF GETVEC_A2B_3WAY _AX, _AY, _BX, _BY OUT _VX1, _VY1, _VX2, _VY2, _VX3, _VY3
  VAR _ANG = ATAN(_BY - _AY, _BX - _AX)
  _VX1 = COS(_ANG): _VY1 = SIN(_ANG)
  _VX2 = COS(_ANG + RAD(15)): _VY2 = SIN(_ANG + RAD(15))
  _VX3 = COS(_ANG - RAD(15)): _VY3 = SIN(_ANG - RAD(15))
END

' 敵との当たり判定処理
DEF COL_ENEMY _SP OUT _HIT
  VAR _RET = SPHITSP(_SP, #SP_ENMY_S, #SP_ENMY_E)
  _HIT = #FALSE
  IF _RET >= 0 THEN
    VAR LIFE = SPVAR(_RET, #ELIFE)
    IF LIFE > 1 THEN
      ' 耐久力がある場合
      BEEP 140
      LIFE = LIFE - 1
      SPVAR _RET, #ELIFE, LIFE
    ELSE
      ' 撃破処理
      SPOFS _RET OUT EX, EY
      EXPLOD01 EX, EY
      SPCLR _RET
      BEEP 13 ' 爆発音
    ENDIF
    SPCLR _SP ' 当たった弾を消去
    _HIT = #TRUE
  ENDIF
END

' 背景オブジェクトとの判定 (モック用ダミー)
DEF COL_BG _SP OUT _HIT
  _HIT = #FALSE
END

' 画面外チェック関数
DEF OUTFSCRN(_X, _Y)
  IF _X < #SCR_X1 - 16 || _X > #SCR_X2 + 16 || _Y < #SCR_Y1 - 16 || _Y > #SCR_Y2 + 16 THEN
    RETURN #TRUE
  ENDIF
  RETURN #FALSE
END

' 爆発エフェクトの生成
DEF EXPLOD01 _X, _Y
  VAR _SP = -1
  FOR I = 500 TO 520 ' エフェクト用領域
    IF SPUSED(I) == 0 THEN _SP = I: BREAK
  NEXT
  IF _SP == -1 THEN RETURN
  
  SPSET _SP, #DSP_EXP01
  SPOFS _SP, _X, _Y
  SPROT _SP, RND(180) ' ランダムに回転させて自然に見せる
  ' スプライトアニメーションの開始 (コマ送り)
  SPANIM _SP, "I", 3, #DSP_EXP01, 3, #DSP_EXP01+1, 3, #DSP_EXP01+2, 1
END

' マップデータの読み込みとBGスプライト配置
DEF DRAW_BGSP
  ' マップデータに基づき、#SP_BGGRID_S 領域にスプライトを並べる処理
END


