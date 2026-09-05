extends RefCounted

## スコープのスクリプトがアタッチされているノードのグループ名
const GROUP_NAME := &"test_group"

## 注入対象として固定利用するメソッド名
const INJECTION_METHOD_NAME := &"inject_dependency"

## 注入する依存クラスで無名クラスを利用したいときに使う[br]
## 引数の型のオーバーライドする用のメソッド名
const OVERRIDE_METHOD_NAME := &"get_inject_type_overrides"
