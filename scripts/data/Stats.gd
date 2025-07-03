# scripts/data/Stats.gd
extends Resource
class_name Stats

@export var max_health: int = 100
@export var current_health: int = 100
@export var attack_power: int = 10
@export var defense: int = 5
@export var speed: int = 10

@export var skill_points: int = 3
@export var max_skill_points: int = 5
@export var ultimate_energy: int = 0
@export var max_ultimate_energy: int = 100

func clone() -> Stats:
    var new_stats = Stats.new()
    new_stats.max_health = max_health
    new_stats.current_health = current_health # 현재 체력은 최대로 시작하거나 별도 관리
    new_stats.attack_power = attack_power
    new_stats.defense = defense
    new_stats.speed = speed
    new_stats.skill_points = skill_points # 초기 스킬 포인트
    new_stats.max_skill_points = max_skill_points
    new_stats.ultimate_energy = ultimate_energy # 초기 궁극기 에너지
    new_stats.max_ultimate_energy = max_ultimate_energy
    return new_stats
