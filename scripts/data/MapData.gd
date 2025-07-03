# scripts/data/MapData.gd
extends Resource
class_name MapData

@export var map_id: String = "unique_map_id"
@export var map_name: String = "맵 이름"
@export var tilemap_scene: PackedScene = null # TileMap을 포함하는 씬
@export var background_music: AudioStream = null
@export var enemy_party: Array[CharacterData] = [] # 이 맵에 등장할 적 캐릭터 데이터 목록
# @export var enemy_positions: Array[Vector2i] = [] # 적 초기 배치 좌표 (TileMap 기준)
