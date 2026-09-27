class_name SolarCycle
extends Node

# NOAA fractional-year solar equations; UTC avoids timezone/DST ambiguity.
# https://gml.noaa.gov/grad/solcalc/solareqns.PDF
static var current_altitude := 45.0
var sun: DirectionalLight3D
var environment: Environment
var sky: ProceduralSkyMaterial
var observer := Vector3.ZERO
var elapsed := 1.0

static func position_at(unix_seconds: float, latitude: float, longitude: float) -> Dictionary:
	var utc := Time.get_datetime_dict_from_unix_time(int(unix_seconds))
	var year: int = utc.year
	var start := Time.get_unix_time_from_datetime_dict({"year":year,"month":1,"day":1,"hour":0,"minute":0,"second":0})
	var days := 366.0 if year % 4 == 0 and (year % 100 != 0 or year % 400 == 0) else 365.0
	var day: float = floor((unix_seconds - start) / 86400.0) + 1
	var hour: float = utc.hour + utc.minute / 60.0 + utc.second / 3600.0
	var gamma := TAU / days * (day - 1 + (hour - 12) / 24.0)
	var equation := 229.18 * (0.000075 + 0.001868*cos(gamma) - 0.032077*sin(gamma) - 0.014615*cos(2*gamma) - 0.040849*sin(2*gamma))
	var declination := 0.006918 - 0.399912*cos(gamma) + 0.070257*sin(gamma) - 0.006758*cos(2*gamma) + 0.000907*sin(2*gamma) - 0.002697*cos(3*gamma) + 0.00148*sin(3*gamma)
	var angle := deg_to_rad(fposmod(hour * 60 + equation + 4 * longitude, 1440) / 4 - 180)
	var lat := deg_to_rad(latitude)
	var up := sin(lat)*sin(declination) + cos(lat)*cos(declination)*cos(angle)
	var east := -cos(declination)*sin(angle)
	var north := cos(lat)*sin(declination) - sin(lat)*cos(declination)*cos(angle)
	return {"direction":Vector3(east, up, -north).normalized(), "altitude":rad_to_deg(asin(clampf(up,-1,1)))}

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 1: return
	elapsed = 0
	update_at(Time.get_unix_time_from_system())

func update_at(unix_seconds: float) -> void:
	var origin: Array = District.DATA.origin_lonlat
	var lon := float(origin[0]) + rad_to_deg(observer.x / (6378137.0 * cos(deg_to_rad(origin[1]))))
	var lat := float(origin[1]) - rad_to_deg(observer.z / 6378137.0)
	var solar := position_at(unix_seconds, lat, lon)
	var direction: Vector3 = solar.direction
	# Directional lights emit along -Z; orient toward the ground, away from the sun.
	sun.basis = Basis.looking_at(-direction, Vector3.UP if absf(direction.y) < 0.999 else Vector3.FORWARD)
	var altitude: float = solar.altitude
	current_altitude = altitude
	var daylight := smoothstep(-6.0, 12.0, altitude)
	var direct := smoothstep(-0.833, 10.0, altitude)
	sun.light_energy = 1.2 * direct
	sun.light_color = Color("ffab68").lerp(Color("fff1d8"), smoothstep(0, 25, altitude))
	sky.sky_top_color = Color("091222").lerp(Color("547da5"), daylight)
	sky.sky_horizon_color = Color("182339").lerp(Color("c8d1d4"), daylight)
	if altitude > -6 and altitude < 12:
		sky.sky_horizon_color = sky.sky_horizon_color.lerp(Color("bc8068"), 0.35 * (1 - absf(altitude - 3) / 9))
	sky.ground_horizon_color = sky.sky_horizon_color
	sky.ground_bottom_color = Color("09111b").lerp(Color("59625d"), daylight)
	environment.ambient_light_energy = lerpf(0.28, 0.65, daylight)
	environment.ambient_light_color = Color("617a9b").lerp(Color("bac6d3"), daylight)
	environment.fog_light_color = sky.sky_horizon_color
