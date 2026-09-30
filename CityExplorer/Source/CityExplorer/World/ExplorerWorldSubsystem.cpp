#include "ExplorerWorldSubsystem.h"
#include "../Core/ExplorerMapSubsystem.h"
#include "ProceduralMeshComponent.h"
#include "CompGeom/PolygonTriangulation.h"
#include "Engine/World.h"
#include "Engine/GameInstance.h"
#include "GameFramework/PlayerController.h"
#include "Materials/MaterialInterface.h"
namespace
{
    struct FTileMesh
    {
        TArray<FVector> Vertices, Normals;
        TArray<FVector2D> UV;
        TArray<FLinearColor> Colors;
        TArray<int32> Indices;
        void Triangle(FVector A, FVector B, FVector C, FLinearColor Color)
        {
            const int32 N = Vertices.Num(); const FVector Normal = FVector::CrossProduct(B - A, C - A).GetSafeNormal();
            for (auto V : {A, B, C}) { Vertices.Add(V); Normals.Add(Normal); UV.Add(FVector2D(V.X, V.Y) / 400); Colors.Add(Color); }
            // Unreal front faces use clockwise winding; normals retain the upward geometric direction.
            Indices.Append({N, N + 2, N + 1});
        }
        void Quad(FVector A, FVector B, FVector C, FVector D, FLinearColor Color) { Triangle(A, B, C, Color); Triangle(A, C, D, Color); }
    };
    FVector2D JsonPoint(const TSharedPtr<FJsonValue>& V) { const auto& A = V->AsArray(); return FVector2D(A[0]->AsNumber(), A[1]->AsNumber()); }
}
AExplorerTile::AExplorerTile()
{
    Mesh = CreateDefaultSubobject<UProceduralMeshComponent>(TEXT("Geometry")); SetRootComponent(Mesh);
    Mesh->bUseComplexAsSimpleCollision = true; Mesh->SetCollisionProfileName(TEXT("BlockAll"));
    Mesh->SetMobility(EComponentMobility::Movable);
}
void AExplorerTile::Build(FIntPoint Cell, UExplorerMapSubsystem& Map, UMaterialInterface* Material)
{
    const FVector2D Origin(Cell.X * 192, Cell.Y * 192); SetActorLocation(FVector(Origin.X * 100, Origin.Y * 100, 0));
    const auto& Terrain = Map.GetTerrain(); FTileMesh Geometry;
    const auto At = [&](FVector2D P, double Offset = 0.0) { return FVector((P.X - Origin.X) * 100, (P.Y - Origin.Y) * 100, (Terrain.Height(P.X, P.Y) + Offset) * 100); };
    for (int32 X = 0; X < 32; ++X) for (int32 Y = 0; Y < 32; ++Y)
    {
        const FVector2D A = Origin + FVector2D(X * 6, Y * 6), B = A + FVector2D(6, 0), C = A + FVector2D(6, 6), D = A + FVector2D(0, 6);
        Geometry.Quad(At(A), At(B), At(C), At(D), FLinearColor(0.36, 0.39, 0.32));
    }
    auto Tile = Map.LoadTile(Cell);
    if (Tile)
    {
        for (const auto& Value : Tile->GetArrayField(TEXT("roads")))
        {
            auto R = Value->AsObject(); const auto A = JsonPoint(MakeShared<FJsonValueArray>(R->GetArrayField(TEXT("a"))));
            const auto B = JsonPoint(MakeShared<FJsonValueArray>(R->GetArrayField(TEXT("b"))));
            const auto D = (B - A).GetSafeNormal(); const FVector2D N(-D.Y, D.X); const double Half = R->GetNumberField(TEXT("width")) / 2;
            const int32 Steps = FMath::Max(1, FMath::CeilToInt((B - A).Size() / 6));
            for (int32 I = 0; I < Steps; ++I)
            {
                const auto P = FMath::Lerp(A, B, double(I) / Steps), Q = FMath::Lerp(A, B, double(I + 1) / Steps);
                Geometry.Quad(At(P - N * (Half + 1.5), 0.08), At(Q - N * (Half + 1.5), 0.08), At(Q + N * (Half + 1.5), 0.08), At(P + N * (Half + 1.5), 0.08), FLinearColor(0.62, 0.59, 0.53));
                Geometry.Quad(At(P - N * Half, 0.12), At(Q - N * Half, 0.12), At(Q + N * Half, 0.12), At(P + N * Half, 0.12), FLinearColor(0.11, 0.12, 0.13));
            }
        }
        for (const auto& Value : Tile->GetArrayField(TEXT("buildings")))
        {
            auto Building = Value->AsObject(); const auto& Rings = Building->GetArrayField(TEXT("rings")); if (Rings.IsEmpty()) continue;
            double Base = -1e9, Low = 1e9;
            for (const auto& V : Rings[0]->AsArray()) { auto P = JsonPoint(V); const double H = Terrain.Height(P.X, P.Y); Base = FMath::Max(Base, H); Low = FMath::Min(Low, H); }
            const double Top = Base + Building->GetNumberField(TEXT("height")) + 0.1;
            const uint32 Seed = GetTypeHash(Building->GetStringField(TEXT("id")));
            const FLinearColor Color(0.55 + (Seed % 7) * 0.025, 0.48 + (Seed % 5) * 0.025, 0.38 + (Seed % 3) * 0.03);
            for (const auto& Ring : Rings)
            {
                const auto& Points = Ring->AsArray();
                for (int32 I = 0; I < Points.Num(); ++I)
                {
                    const auto P = JsonPoint(Points[I]), Q = JsonPoint(Points[(I + 1) % Points.Num()]);
                    const FVector A((P.X - Origin.X) * 100, (P.Y - Origin.Y) * 100, (Low - 0.1) * 100), B((Q.X - Origin.X) * 100, (Q.Y - Origin.Y) * 100, (Low - 0.1) * 100);
                    const FVector C(B.X, B.Y, Top * 100), D(A.X, A.Y, Top * 100);
                    Geometry.Quad(A, B, C, D, Color); Geometry.Quad(D, C, B, A, Color);
                }
            }
            // Match Godot: do not cover courtyard holes with a false solid roof.
            if (Rings.Num() == 1)
            {
                TArray<FVector2D> Poly; for (const auto& V : Rings[0]->AsArray()) Poly.Add(JsonPoint(V));
                TArray<UE::Geometry::FIndex3i> Triangles; PolygonTriangulation::TriangulateSimplePolygon(Poly, Triangles, false);
                const auto Roof = [&](int32 I) { return FVector((Poly[I].X - Origin.X) * 100, (Poly[I].Y - Origin.Y) * 100, Top * 100); };
                for (auto T : Triangles) { auto A = Roof(T.A), B = Roof(T.B), C = Roof(T.C); if (FVector::CrossProduct(B - A, C - A).Z < 0) Swap(B, C); Geometry.Triangle(A, B, C, FLinearColor(0.35, 0.32, 0.28)); }
            }
        }
    }
    Mesh->CreateMeshSection_LinearColor(0, Geometry.Vertices, Geometry.Indices, Geometry.Normals, Geometry.UV, Geometry.Colors, {}, true);
    if (Material) Mesh->SetMaterial(0, Material);
}
bool UExplorerWorldSubsystem::DoesSupportWorldType(EWorldType::Type Type) const { return Type == EWorldType::Game || Type == EWorldType::PIE; }
void UExplorerWorldSubsystem::LoadOne(FIntPoint Cell)
{
    if (Active.Contains(Cell)) return;
    auto* Map = GetWorld()->GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>(); if (!Map || !Map->IsReady()) return;
    if (!Material) Material = LoadObject<UMaterialInterface>(nullptr, TEXT("/Game/CityExplorer/Materials/M_CityVertexColor.M_CityVertexColor"));
    auto* Tile = GetWorld()->SpawnActor<AExplorerTile>(); Tile->Build(Cell, *Map, Material); Active.Add(Cell, Tile);
}
void UExplorerWorldSubsystem::StreamAt(FVector Position, bool Immediate)
{
    auto* Map = GetWorld()->GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>(); if (!Map || !Map->IsReady()) return;
    const FVector2D P(Position.X / 100, Position.Y / 100); const FIntPoint Cell(FMath::FloorToInt(P.X / 192), FMath::FloorToInt(P.Y / 192));
    if (Cell == LastCell && !Immediate) return; LastCell = Cell;
    Desired = Map->RequiredTiles(P); Pending.Reset();
    const auto Critical = Map->RequiredTiles(P, 1);
    for (auto C : Critical) LoadOne(C);
    for (auto C : Desired) if (Immediate) LoadOne(C); else if (!Active.Contains(C)) Pending.Add(C);
    for (auto It = Active.CreateIterator(); It; ++It) if (!Desired.Contains(It.Key())) { It.Value()->Destroy(); It.RemoveCurrent(); }
}
void UExplorerWorldSubsystem::Tick(float Delta)
{
    if (auto* PC = GetWorld()->GetFirstPlayerController()) if (APawn* Pawn = PC->GetPawn()) StreamAt(Pawn->GetActorLocation(), false);
    if (!Pending.IsEmpty()) LoadOne(Pending.Pop());
}
