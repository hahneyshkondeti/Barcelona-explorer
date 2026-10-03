#include "ExplorerSessionSubsystem.h"
#include "ExplorerMapSubsystem.h"
#include "Kismet/GameplayStatics.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "AudioDevice.h"
namespace { const FString Slot = TEXT("CityExplorerUnrealJourney_v1"); }
void UExplorerSessionSubsystem::Initialize(FSubsystemCollectionBase& Collection)
{
    Super::Initialize(Collection);
    auto* Loaded = Cast<UExplorerSaveGame>(UGameplayStatics::LoadGameFromSlot(Slot, 0));
    Preferences = Loaded && Loaded->Version == 1 ? Loaded : NewObject<UExplorerSaveGame>(this);
    Preferences->FrameCap = Preferences->FrameCap == 60 ? 60 : 30;
    if (Preferences->Theme != TEXT("dark") && Preferences->Theme != TEXT("light") && Preferences->Theme != TEXT("system")) Preferences->Theme = TEXT("dark");
    Preferences->CityId = TEXT("barcelona"); Preferences->VehicleId = TEXT("touring_car");
    if (Preferences->SafePosition.ContainsNaN() || Preferences->Heading.ContainsNaN()) Preferences->bHasJourney = false;
}
void UExplorerSessionSubsystem::SetScreen(EExplorerScreen Value)
{
    if (Screen == Value) return;
    Screen = Value; OnScreenChanged.Broadcast(Screen);
}
bool UExplorerSessionSubsystem::SavePreferences()
{
    return Preferences && UGameplayStatics::SaveGameToSlot(Preferences, Slot, 0);
}
bool UExplorerSessionSubsystem::RecordSafePosition(FVector Position, FRotator Rotation)
{
    if (!Preferences || Position.ContainsNaN() || Rotation.ContainsNaN()) return false;
    auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>();
    if (!Map || !Map->IsReady()) return false;
    const FVector2D Point(Position.X / 100, Position.Y / 100); const auto Hit = Map->NearestRoad(Point);
    if (Hit.Road == INDEX_NONE || Hit.Distance >= 4 || FMath::Abs(Position.Z / 100 - Map->GetTerrain().Height(Point.X, Point.Y)) >= 3) return false;
    FVector Safe; FRotator Heading;
    if (!Map->SafeSpawn(Point, Safe, Heading)) return false;
    Preferences->SafePosition = Safe; Preferences->Heading = Rotation; Preferences->bHasJourney = true;
    return SavePreferences();
}

void UExplorerSessionSubsystem::ApplyAudioPreference()
{
    if (Preferences && GetWorld()) if (auto Audio = GetWorld()->GetAudioDevice()) Audio->SetTransientPrimaryVolume(Preferences->bMuted ? 0.f : 1.f);
}
