#include "Misc/AutomationTest.h"
#include <limits>
#include "Engine/GameInstance.h"
#include "../Core/ExplorerHandling.h"
#include "../Core/ExplorerTerrain.h"
#include "../Core/ExplorerMapSubsystem.h"
#if WITH_DEV_AUTOMATION_TESTS
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FExplorerHandlingTest, "CityExplorer.Core.Handling", EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)
bool FExplorerHandlingTest::RunTest(const FString& Parameters)
{
    FExplorerHandling H;
    for (int32 I = 0; I < 60; ++I) H.Step(1.0 / 60, 0, 0, 1);
    TestEqual(TEXT("Steering at rest has no yaw"), H.YawRate, 0.0);
    H.Reset();
    for (int32 I = 0; I < 60 * 40; ++I) H.Step(1.0 / 60, 1, 0, 0);
    TestTrue(TEXT("150 km/h cap"), FMath::Abs(H.Speed - FExplorerHandling::MaxSpeed) < 0.01);
    for (int32 I = 0; I < 60; ++I) H.Step(1.0 / 60, 1, 0, 1);
    TestTrue(TEXT("Lateral acceleration limited"), FMath::Abs(H.YawRate * H.Speed) <= 6.5001);
    double Distance = 0;
    while (H.Speed > 0) { H.Step(1.0 / 60, 0, 1, 0); Distance += H.Speed / 60; }
    TestTrue(TEXT("Braking distance below 52 metres"), Distance < 52);
    H.Reset();
    for (int32 I = 0; I < 18; ++I) H.Step(1.0 / 60, 0, 1, 0);
    TestEqual(TEXT("Reverse waits at least 0.35 seconds"), H.Speed, 0.0);
    for (int32 I = 0; I < 300; ++I) H.Step(1.0 / 60, 0, 1, 1);
    TestEqual(TEXT("Reverse speed cap"), H.Speed, -5.0);
    TestTrue(TEXT("Reverse changes yaw direction"), H.YawRate < 0);
    for (int32 I = 0; I < 120; ++I) H.Step(1.0 / 60, 1, 1, 0);
    TestEqual(TEXT("Both pedals stop without reverse"), H.Speed, 0.0);
    double Speeds[3]; int32 Index = 0;
    for (int32 Rate : {30, 60, 120})
    {
        H.Reset(); for (int32 I = 0; I < Rate * 5; ++I) H.Step(1.0 / Rate, 1, 0, 0);
        Speeds[Index++] = H.Speed;
    }
    TestTrue(TEXT("Frame rate consistency"), FMath::Abs(Speeds[0] - Speeds[2]) < 0.15);
    return true;
}
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FExplorerTerrainTest, "CityExplorer.Core.Terrain", EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)
bool FExplorerTerrainTest::RunTest(const FString& Parameters)
{
    FExplorerTerrain T; T.Columns = T.Rows = 2; T.Spacing = 1; T.Samples = {0, 10, 20, 100};
    TestEqual(TEXT("NW-SE upper triangle"), T.Height(0.75, 0.25), 30.0);
    TestEqual(TEXT("NW-SE lower triangle"), T.Height(0.25, 0.75), 35.0);
    TestEqual(TEXT("Diagonal agrees on both triangles"), T.Height(0.5, 0.5), 50.0);
    TestEqual(TEXT("Clamp before origin"), T.Height(-2, -2), 0.0);
    TestEqual(TEXT("Clamp beyond grid"), T.Height(3, 3), 100.0);
    return true;
}
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FExplorerMapTest, "CityExplorer.Core.OfflineMap", EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)
bool FExplorerMapTest::RunTest(const FString& Parameters)
{
    auto* Map = NewObject<UExplorerMapSubsystem>(NewObject<UGameInstance>());
    TestTrue(TEXT("Offline city loads"), Map->LoadCity());
    if (!Map->IsReady()) return false;
    TestEqual(TEXT("Connected road count"), Map->GetRoads().Num(), 126836);
    FVector Position; FRotator Rotation;
    TestTrue(TEXT("Default start resolves to safe road"), Map->SafeSpawn(Map->GetStart(), Position, Rotation));
    TestTrue(TEXT("Unreal position uses centimetres"), FMath::Abs(Position.Z / 100 - Map->GetTerrain().Height(Position.X / 100, Position.Y / 100) - 0.75) < 0.0001);
    TestFalse(TEXT("Out-of-bounds spawn rejected"), Map->SafeSpawn(FVector2D(1e6, 1e6), Position, Rotation));
    TestFalse(TEXT("NaN spawn rejected"), Map->SafeSpawn(FVector2D(std::numeric_limits<double>::quiet_NaN(), 0), Position, Rotation));
    TestTrue(TEXT("Ownership dependencies expand neighborhood"), Map->RequiredTiles(Map->GetStart()).Num() >= 25);
    TestEqual(TEXT("Accent normalization"), UExplorerMapSubsystem::Normalize(TEXT("Sagrada Família")), FString(TEXT("sagrada familia")));
    TestTrue(TEXT("Reverse address range contains 12"), UExplorerMapSubsystem::NumberMatches(TEXT("12"), TEXT("16-12")));
    TestFalse(TEXT("Address range does not invent missing number"), UExplorerMapSubsystem::NumberMatches(TEXT("18"), TEXT("16-12")));
    TestTrue(TEXT("Recorded address query returns results"), Map->SearchOffline(TEXT("Carrer Gretel Ammann Martinez 12")).Num() > 0);
    return true;
}
IMPLEMENT_SIMPLE_AUTOMATION_TEST(FExplorerDirectedRouteTest, "CityExplorer.Core.DirectedRoute", EAutomationTestFlags::EditorContext | EAutomationTestFlags::EngineFilter)
bool FExplorerDirectedRouteTest::RunTest(const FString& Parameters)
{
    TArray<FExplorerRoad> Roads;
    auto Add = [&](FString AId, FString BId, FVector2D A, FVector2D B) { FExplorerRoad R; R.AId = AId; R.BId = BId; R.A = A; R.B = B; R.OneWay = 1; Roads.Add(R); };
    Add(TEXT("a"), TEXT("b"), {0, 0}, {10, 0});
    FExplorerRoadHit S, F; S.Road = F.Road = 0; S.Point = {2, 0}; F.Point = {8, 0};
    FExplorerRoadGraph Graph; Graph.Build(Roads);
    TestEqual(TEXT("Allowed partial edge routes directly"), Graph.Route(Roads, S, F).Num(), 2);
    Swap(S.Point, F.Point);
    TestTrue(TEXT("Forbidden reverse direction is unreachable"), Graph.Route(Roads, S, F).IsEmpty());
    Add(TEXT("b"), TEXT("c"), {10, 0}, {10, 10}); Add(TEXT("c"), TEXT("a"), {10, 10}, {0, 0}); Graph.Build(Roads);
    const auto Detour = Graph.Route(Roads, S, F);
    TestTrue(TEXT("Reverse partial edge takes permitted directed loop"), Detour.Num() >= 5);
    if (!Detour.IsEmpty()) { TestEqual(TEXT("Detour starts at partial edge"), Detour[0], S.Point); TestEqual(TEXT("Detour ends at partial edge"), Detour.Last(), F.Point); }
    return true;
}
#endif
