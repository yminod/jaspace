# jaspace.el provenance

この文書は、jaspace.el の現存資料をどこから取得し、何を upstream の
原典と判断したかを記録する。人物の同定よりも、ソース自身の記載と再取得可能な
アーカイブを優先する。

## Upstream の表示

- Author: `Satomi I.`
- 旧連絡先: `satomi@ring.gr.jp`、後期版では
  `satomi atmark ring period gr period jp`
- License: GNU General Public License version 2 or later
- 確認できている最終版: 1.1
- 最終版ソース内の日付: 2005-02-26 06:21:02

移転後サイトのトップには `satomi@openlab.edict` および
`Copyright 2000-2005 satomi / rei` とある。しかし、この表示だけから
`Satomi I.` の実名や「rei」との関係を確定することはできない。この
リポジトリでは原典の表記どおり `Satomi I.` を著者名として残す。

## サイトの所在

確認できた旧所在地と移転後の所在地は次のとおり。

- 旧サイト: <http://member.nifty.ne.jp/~satomii/>
- 移転後: <http://homepage3.nifty.com/satomii/>
- [移転後トップの2004年保存](https://web.archive.org/web/20040924181808id_/http://homepage3.nifty.com/satomii/index.html)
- [移転後トップの2007年保存](https://web.archive.org/web/20070112075245id_/http://homepage3.nifty.com/satomii/index.html)
- [GNU Emacs向け配布ページの2015年保存](https://web.archive.org/web/20150710163612/http://homepage3.nifty.com/satomii/software/elisp.ja.html)

移転後トップには旧所在地へのリンクはないが、当時の第三者資料には
`member.nifty.ne.jp/~satomii/` 以下の FreePWING および software ページへの
参照が残っている。また、旧所在地の jaspace.el が Wayback Machine に保存
されているため、旧所在地であったことを直接確認できる。

## 確認できた版

| Version | ソース内の日付 | 保存資料または取得元 | 備考 |
| --- | --- | --- | --- |
| 0.1.0.9 | 2002-09-23 | [旧サイトの2004-03-06保存](https://web.archive.org/web/20040306093401id_/http://member.nifty.ne.jp:80/~satomii/software/jaspace-0.1.0.9.el) | 現存を確認できた最古の版 |
| 1.0.0.3 | 2003-05-19 | [`jaspace-1.0.0.3.el.gz`](https://web.archive.org/web/20150710163612/http://homepage3.nifty.com/satomii/software/jaspace-1.0.0.3.el.gz) | ローカル保存あり |
| 1.0.0.5 | 2003-06-08 | [`jaspace-1.0.0.5.el.gz`](https://web.archive.org/web/20150710163612/http://homepage3.nifty.com/satomii/software/jaspace-1.0.0.5.el.gz) | ローカル保存あり |
| 1.0.0.7 | 2004-04-22 | [`jaspace-1.0.0.7.el.gz`](https://web.archive.org/web/20150710163612/http://homepage3.nifty.com/satomii/software/jaspace-1.0.0.7.el.gz) | ローカル保存あり |
| 1.0.0.9 | 2004-06-21 | [移転後サイトの2004-08-07保存](https://web.archive.org/web/20040807074325id_/http://homepage3.nifty.com:80/satomii/software/jaspace.el) | 配布ページの個別リンクは誤っているが、通常名の保存から回収可能 |
| 1.1 | 2005-02-26 | [移転後サイトの2012-04-15保存](https://web.archive.org/web/20120415192313id_/http://homepage3.nifty.com:80/satomii/software/jaspace.el) | 確認できている最終版 |

0.1.0.9 は、ソース先頭の `$Id` では 0.1.0.9 だが、別のヘッダー行が
`Version: 0.1.0.3` のままになっている。作者側の更新漏れと考えるのが自然だが、
原典は修正せず、この不一致をそのまま記録する。

2015年保存の配布ページでは `jaspace-1.0.0.9.el.gz` と表示されたリンクが
`jaspace-1.0.0.7.el.gz` を指している。1.0.0.9 は上表の通常名
`jaspace.el` の2004年保存から取得できる。

## 最終版と判断した根拠

[jaspace.el の CDX 保存履歴](https://web.archive.org/cdx/search/cdx?url=homepage3.nifty.com%2Fsatomii%2Fsoftware%2Fjaspace.el&output=json)
には、2004年から2012年まで19件の取得がある。内容のdigestは実質2種類で、
2005-04-14以降は同じ内容である。その内容は `$Id: jaspace.el 1.1
2005/02/26 06:21:02 satomii Exp $` と名乗る。2015年保存の配布ページも
通常名 `jaspace.el` を 1.1 と表示している。このため、1.1 を確認可能な
upstream 最終版とする。

これは「作者がその後一切変更しなかった」ことの証明ではなく、公開サイトと
Wayback Machine から確認できる範囲での結論である。

## ハッシュ

### Wayback Machineから取得できる未圧縮ソース

| Version | Bytes | SHA-256 |
| --- | ---: | --- |
| 0.1.0.9 | 9,988 | `5732a6fb37b5e3596a94b1ca89b68954efc9ea8c64090d3b10b9546cac2b92fc` |
| 1.0.0.9 | 15,955 | `5bc8427024d75470046bb897a23d47fbc8f49fa2aa39aaf60c702c181475deaa` |
| 1.1 | 19,084 | `f6e4d23cc8fb4cfd1b8c84dcb04df094f070200fdc96f69f3b192fcda5bc2b22` |

ローカルの `ref/jaspace-0.1.0.9.el.gz` を展開した内容は、上記の旧サイト
保存版とCRLFを含めてバイト単位で一致した。

### ローカルに保存されたgzipファイル

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| `ref/jaspace-0.1.0.9.el.gz` | 3,104 | `444c2b4bff2353e79f39085b8dd9fbdbf5965ca56b772dac85b6a84933d50676` |
| `ref/jaspace-1.0.0.3.el.gz` | 3,271 | `6694ef42eb7a9d5bf17e9be60645b8e75476d2269112f4f3f0186cedeaf8535c` |
| `ref/jaspace-1.0.0.5.el.gz` | 3,226 | `9e5ff3a6c61fbbbce7487026b231280a31729e4b8c9afd9b6be8425d22ca773a` |
| `ref/jaspace-1.0.0.7.el.gz` | 3,581 | `143187e3beb140dd32df7fe39484d0179a11cea45912ce8cce5d0976c154ff42` |

展開後のSHA-256は次のとおり。

| Version | Bytes | SHA-256 |
| --- | ---: | --- |
| 0.1.0.9 | 9,988 | `5732a6fb37b5e3596a94b1ca89b68954efc9ea8c64090d3b10b9546cac2b92fc` |
| 1.0.0.3 | 10,626 | `7edefe83d14698748e7bc0e10befb892a8dd29939666f2813a12650fea06d993` |
| 1.0.0.5 | 10,629 | `47f06ba2911ec5a3d91906f37c3c86cd4ace1b38801ae5d070a638757f22ade0` |
| 1.0.0.7 | 11,796 | `82982e5663850afbc01ecebeb82b919bcc6e072e61a1a63060e1ebdd61f2825e` |

## 調査開始時のファイル状態

調査開始時、ディレクトリ直下の `jaspace.el` は Lisp ソースではなく、
2012-04-15保存のソースを iframe で再生する Wayback Machine のラッパーHTML
だった。これは `ref/wayback-20120415192313-jaspace-wrapper.html` へ退避し、
直下のファイルを上記の未改変1.1と置き換えた。原典のコミットには
`upstream/1.1` タグを付けた。

個人設定内で実際に使用されていたコピーは1.1を元に修正されていたが、警告を
避けるための試行錯誤を含むため、upstream 原典としては採用しない。必要な変更は
後から個別の差分として検討する。

## 参考アセットの扱い

旧版 `.el` / `.el.gz` は GPL 表記を含むソースであり、版間比較や不具合の由来を
調べる一次資料になるため、保存対象とする。

配布ページのHTML、画像、Wayback再生用のJavaScriptやCSSは、jaspace.elの
ライセンスが当然に及ぶとは限らない。とくに再生用アセットは実装調査にも不要で
ある。公開リポジトリには原則として含めず、この文書のURLとハッシュから再調査
できるようにする。ローカルに保存済みの資料は、リポジトリへ収録する範囲を
決めるまで削除しない。

保存ページ本体 `おまけ for GNU Emacs.htm` の調査時点のSHA-256は
`747ee821fc7f820f7b82a41db7e714b8d8f06825835f8c939a49fa2ad443d02c`
である。
