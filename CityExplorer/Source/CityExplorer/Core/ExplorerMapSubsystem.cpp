#include "ExplorerMapSubsystem.h"
#include "Misc/FileHelper.h"
#include "Misc/Paths.h"
#include "Serialization/JsonReader.h"
#include "Serialization/JsonSerializer.h"
namespace
{
    TSharedPtr<FJsonObject> ReadJson(const FString& Path)
    {
        FString Text; TSharedPtr<FJsonObject> Object;
        if (FFileHelper::LoadFileToString(Text, *Path)) FJsonSerializer::Deserialize(TJsonReaderFactory<>::Create(Text), Object);
        return Object;
    }
    FVector2D Point(const TArray<TSharedPtr<FJsonValue>>& V) { return FVector2D(V[0]->AsNumber(), V[1]->AsNumber()); }
    FIntPoint CellKey(const FString& Key)
    {
        FString A, B; Key.Split(TEXT(":"), &A, &B); return FIntPoint(FCString::Atoi(*A), FCString::Atoi(*B));
    }
    bool WordsMatch(const FString& Query, const FString& Value)
    {
        TArray<FString> Words; Query.ParseIntoArrayWS(Words);
        for (const FString& W : Words)
        {
            if (W == TEXT("de") || W == TEXT("del") || W == TEXT("la") || W == TEXT("el") || W == TEXT("carrer") || W == TEXT("calle")) continue;
            if (!Value.Contains(W)) return false;
        }
        return true;
    }
}
bool UExplorerMapSubsystem::LoadCity()
{
    if (bReady) return true;
    DataRoot = FPaths::Combine(FPaths::ProjectContentDir(), TEXT("CityExplorer/Data/Offline"));
#if WITH_EDITOR
    if (!FPaths::FileExists(FPaths::Combine(DataRoot, TEXT("city/manifest.json"))))
        DataRoot = FPaths::ConvertRelativePathToFull(FPaths::Combine(FPaths::ProjectDir(), TEXT("../data")));
#endif
    auto Manifest = ReadJson(FPaths::Combine(DataRoot, TEXT("city/manifest.json")));
    if (!Manifest || Manifest->GetIntegerField(TEXT("schema")) != 2) { LastError = TEXT("Missing or incompatible offline city data"); return false; }
    if (!Terrain.Load(DataRoot, LastError)) return false;
    Roads.Reset(); RoadCells.Reset(); Places.Reset(); Dependencies.Reset(); Tiles.Reset();
    Start = Point(Manifest->GetArrayField(TEXT("start")));
    OriginLonLat = Point(Manifest->GetArrayField(TEXT("origin_lonlat")));
    const auto& Bounds = Manifest->GetArrayField(TEXT("bounds"));
    BoundsMin = Point(Bounds[0]->AsArray()); BoundsMax = Point(Bounds[1]->AsArray());
    for (const auto& Value : Manifest->GetArrayField(TEXT("roads")))
    {
        auto R = Value->AsObject(); if (!R->GetBoolField(TEXT("routable"))) continue;
        FExplorerRoad Road; Road.Id = R->GetStringField(TEXT("id")); Road.Name = R->GetStringField(TEXT("name"));
        Road.AId = R->GetStringField(TEXT("a_id")); Road.BId = R->GetStringField(TEXT("b_id"));
        Road.A = Point(R->GetArrayField(TEXT("a"))); Road.B = Point(R->GetArrayField(TEXT("b")));
        Road.Width = R->GetNumberField(TEXT("width")); Road.OneWay = R->GetIntegerField(TEXT("oneway"));
        const int32 Index = Roads.Add(Road);
        for (int32 X = FMath::FloorToInt(FMath::Min(Road.A.X, Road.B.X) / 192); X <= FMath::FloorToInt(FMath::Max(Road.A.X, Road.B.X) / 192); ++X)
            for (int32 Y = FMath::FloorToInt(FMath::Min(Road.A.Y, Road.B.Y) / 192); Y <= FMath::FloorToInt(FMath::Max(Road.A.Y, Road.B.Y) / 192); ++Y)
                RoadCells.FindOrAdd(FIntPoint(X, Y)).Add(Index);
    }
    for (const auto& Value : Manifest->GetArrayField(TEXT("places")))
    {
        auto R = Value->AsObject(); FExplorerPlace P; P.Id = R->GetStringField(TEXT("id")); P.Name = R->GetStringField(TEXT("name"));
        P.Point = Point(R->GetArrayField(TEXT("point"))); P.Address = R->GetStringField(TEXT("street")) + TEXT(" ") + R->GetStringField(TEXT("number")); Places.Add(P);
    }
    for (const auto& Pair : Manifest->GetObjectField(TEXT("tiles"))->Values)
    {
        FString Relative = Pair.Value->AsString(); Relative.RemoveFromStart(TEXT("res://data/"));
        if (!Relative.Contains(TEXT("..")) && FPaths::IsRelative(Relative))
            Tiles.Add(CellKey(FString(Pair.Key)), FPaths::Combine(DataRoot, Relative));
    }
    for (const auto& Pair : Manifest->GetObjectField(TEXT("tile_dependencies"))->Values)
    {
        auto& List = Dependencies.FindOrAdd(CellKey(FString(Pair.Key)));
        for (const auto& Value : Pair.Value->AsArray()) List.Add(CellKey(Value->AsString()));
    }
    Graph.Build(Roads);
    AddressIndex = ReadJson(FPaths::Combine(DataRoot, TEXT("city/address_index.json")));
    bReady = Roads.Num() > 0 && AddressIndex.IsValid();
    if (!bReady) LastError = TEXT("Incomplete road or address index");
    return bReady;
}
FExplorerRoadHit UExplorerMapSubsystem::NearestRoad(FVector2D P) const
{
    FExplorerRoadHit Hit;
    if (!bReady || !FMath::IsFinite(P.X) || !FMath::IsFinite(P.Y)) return Hit;
    const FIntPoint Center(FMath::FloorToInt(P.X / 192), FMath::FloorToInt(P.Y / 192));
    TSet<FIntPoint> Visited;
    for (int32 Radius : {0, 1, 2, 4, 8, 16, 32, 64, 128})
    {
        for (int32 X = Center.X - Radius; X <= Center.X + Radius; ++X)
            for (int32 Y = Center.Y - Radius; Y <= Center.Y + Radius; ++Y)
            {
                const FIntPoint Cell(X, Y); if (Visited.Contains(Cell)) continue; Visited.Add(Cell);
                const auto* List = RoadCells.Find(Cell); if (!List) continue;
                for (int32 Index : *List)
                {
                    const auto& R = Roads[Index]; const FVector2D D = R.B - R.A;
                    const double T = D.SizeSquared() > 0 ? FMath::Clamp(FVector2D::DotProduct(P - R.A, D) / D.SizeSquared(), 0.0, 1.0) : 0;
                    const FVector2D Q = R.A + T * D; const double Distance = (Q - P).Size();
                    if (Distance < Hit.Distance) { Hit.Road = Index; Hit.Point = Q; Hit.Distance = Distance; }
                }
            }
        const double Edge = FMath::Min(FMath::Min(P.X - (Center.X - Radius) * 192, (Center.X + Radius + 1) * 192 - P.X),
                                      FMath::Min(P.Y - (Center.Y - Radius) * 192, (Center.Y + Radius + 1) * 192 - P.Y));
        if (Hit.Distance < Edge) break;
    }
    return Hit;
}
bool UExplorerMapSubsystem::SafeSpawn(FVector2D P, FVector& OutPosition, FRotator& OutRotation) const
{
    if (!bReady || !FMath::IsFinite(P.X) || !FMath::IsFinite(P.Y) || P.X < BoundsMin.X + 3 || P.Y < BoundsMin.Y + 3 || P.X >= BoundsMax.X - 3 || P.Y >= BoundsMax.Y - 3) return false;
    const auto Hit = NearestRoad(P); if (Hit.Road == INDEX_NONE) return false;
    const auto Q = Hit.Point;
    if (Q.X < BoundsMin.X + 3 || Q.Y < BoundsMin.Y + 3 || Q.X >= BoundsMax.X - 3 || Q.Y >= BoundsMax.Y - 3 || Terrain.Height(Q.X, Q.Y) <= -0.5) return false;
    const auto& Road = Roads[Hit.Road]; FVector2D Direction = Road.B - Road.A; if (Road.OneWay == -1) Direction *= -1;
    OutPosition = ToUnreal(Q, Terrain.Height(Q.X, Q.Y) + 0.75);
    OutRotation = FRotator(0, FMath::RadiansToDegrees(FMath::Atan2(Direction.Y, Direction.X)), 0);
    return true;
}
TSet<FIntPoint> UExplorerMapSubsystem::RequiredTiles(FVector2D P, int32 Radius) const
{
    TSet<FIntPoint> Result; Radius = FMath::Clamp(Radius, 0, 8);
    const FIntPoint Center(FMath::FloorToInt(P.X / 192), FMath::FloorToInt(P.Y / 192));
    for (int32 X = Center.X - Radius; X <= Center.X + Radius; ++X)
        for (int32 Y = Center.Y - Radius; Y <= Center.Y + Radius; ++Y)
        {
            const FIntPoint Cell(X, Y); Result.Add(Cell);
            if (const auto* Owners = Dependencies.Find(Cell)) for (FIntPoint Owner : *Owners) Result.Add(Owner);
        }
    return Result;
}
TSharedPtr<FJsonObject> UExplorerMapSubsystem::LoadTile(FIntPoint Cell) const
{
    const auto* Path = Tiles.Find(Cell); return Path ? ReadJson(*Path) : nullptr;
}
FVector2D UExplorerMapSubsystem::ProjectLonLat(double Longitude, double Latitude) const
{
    return FVector2D(FMath::DegreesToRadians(Longitude - OriginLonLat.X) * 6378137 * FMath::Cos(FMath::DegreesToRadians(OriginLonLat.Y)),
                     -FMath::DegreesToRadians(Latitude - OriginLonLat.Y) * 6378137);
}
FString UExplorerMapSubsystem::Normalize(const FString& Value)
{
    FString Result = Value.ToLower();
    const TCHAR* Groups[] = {TEXT("àáâä"), TEXT("èéêë"), TEXT("ìíîï"), TEXT("òóôö"), TEXT("ùúûü"), TEXT("ç"), TEXT("ñ")};
    const TCHAR Replacements[] = {TEXT('a'), TEXT('e'), TEXT('i'), TEXT('o'), TEXT('u'), TEXT('c'), TEXT('n')};
    for (TCHAR& Ch : Result)
    {
        for (int32 I = 0; I < 7; ++I) if (FCString::Strchr(Groups[I], Ch)) { Ch = Replacements[I]; break; }
        if (FCString::Strchr(TEXT("·,.'’- /"), Ch)) Ch = TEXT(' ');
    }
    return Result;
}
bool UExplorerMapSubsystem::NumberMatches(const FString& Query, const FString& Number)
{
    if (Query.IsEmpty() || Query == Number.ToLower()) return true;
    FString A, B;
    if (Query.IsNumeric() && Number.Split(TEXT("-"), &A, &B) && A.IsNumeric() && B.IsNumeric())
    {
        const int32 N = FCString::Atoi(*Query), Lo = FCString::Atoi(*A), Hi = FCString::Atoi(*B);
        return N >= FMath::Min(Lo, Hi) && N <= FMath::Max(Lo, Hi);
    }
    return false;
}
TArray<FExplorerPlace> UExplorerMapSubsystem::SearchOffline(const FString& Query, int32 Limit)
{
    TArray<FExplorerPlace> Result; if (!LoadCity() || Query.TrimStartAndEnd().Len() < 2) return Result;
    Limit = FMath::Clamp(Limit, 1, 300); const FString Clean = Normalize(Query);
    TArray<FString> Tokens; Clean.ParseIntoArrayWS(Tokens); FString Number, Words;
    for (const auto& T : Tokens) { if (T.IsNumeric()) Number = T; else Words += T + TEXT(" "); }
    if (!Words.TrimStartAndEnd().IsEmpty())
    {
        TSet<FIntPoint> ReadCells;
        for (const auto& Street : AddressIndex->Values)
        {
            if (!WordsMatch(Words, Normalize(FString(Street.Key)))) continue;
            for (const auto& TileKey : Street.Value->AsArray())
            {
                const FIntPoint Cell = CellKey(TileKey->AsString()); if (ReadCells.Contains(Cell)) continue; ReadCells.Add(Cell);
                auto Tile = LoadTile(Cell); if (!Tile) continue;
                for (const auto& V : Tile->GetArrayField(TEXT("addresses")))
                {
                    auto R = V->AsObject(); const FString Name = R->GetStringField(TEXT("street")), N = R->GetStringField(TEXT("number"));
                    if (!WordsMatch(Words, Normalize(Name)) || !NumberMatches(Number, N)) continue;
                    FExplorerPlace P; P.Id = R->GetStringField(TEXT("id")); P.Name = Name + TEXT(" ") + N; P.Address = P.Name;
                    P.Point = Point(R->GetArrayField(TEXT("point"))); Result.Add(P); if (Result.Num() >= Limit) return Result;
                }
            }
        }
    }
    for (const auto& P : Places)
    {
        if (WordsMatch(Clean, Normalize(P.Name + TEXT(" ") + P.Address))) { Result.Add(P); if (Result.Num() >= Limit) break; }
    }
    return Result;
}
