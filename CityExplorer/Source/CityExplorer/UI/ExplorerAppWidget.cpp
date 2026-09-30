#include "ExplorerAppWidget.h"
#include "../Core/ExplorerPlaceSearchSubsystem.h"
#include "../Core/ExplorerGameMode.h"
#include "../Vehicles/ExplorerVehicle.h"
#include "Blueprint/WidgetTree.h"
#include "Components/VerticalBox.h"
#include "Components/Border.h"
#include "Components/TextBlock.h"
#include "Components/Button.h"
#include "Components/EditableTextBox.h"
#include "Components/ComboBoxString.h"
#include "Components/CanvasPanel.h"
#include "Components/CanvasPanelSlot.h"
#include "Engine/GameInstance.h"
#include "Engine/World.h"
#include "Engine/Engine.h"
#include "TimerManager.h"
UExplorerSessionSubsystem* UExplorerAppWidget::Session() const { return GetGameInstance()->GetSubsystem<UExplorerSessionSubsystem>(); }
TSharedRef<SWidget> UExplorerAppWidget::RebuildWidget()
{
    RebuildScreen(Session()->Screen); return Super::RebuildWidget();
}
void UExplorerAppWidget::NativeConstruct()
{
    Super::NativeConstruct(); Session()->OnScreenChanged.AddDynamic(this, &UExplorerAppWidget::RebuildScreen);
    auto* Service = GetGameInstance()->GetSubsystem<UExplorerPlaceSearchSubsystem>();
    Service->OnResults.AddDynamic(this, &UExplorerAppWidget::ReceiveResults);
    Service->OnResolved.AddDynamic(this, &UExplorerAppWidget::ReceiveResolved);
    Service->OnError.AddDynamic(this, &UExplorerAppWidget::ReceiveError);
    RebuildScreen(Session()->Screen); GetWorld()->GetTimerManager().SetTimer(RefreshTimer, this, &UExplorerAppWidget::Refresh, 0.1, true);
}
void UExplorerAppWidget::NativeDestruct()
{
    Session()->OnScreenChanged.RemoveDynamic(this, &UExplorerAppWidget::RebuildScreen);
    auto* Service = GetGameInstance()->GetSubsystem<UExplorerPlaceSearchSubsystem>();
    Service->OnResults.RemoveAll(this); Service->OnResolved.RemoveAll(this); Service->OnError.RemoveAll(this);
    GetWorld()->GetTimerManager().ClearTimer(RefreshTimer); Super::NativeDestruct();
}
UTextBlock* UExplorerAppWidget::Text(const FString& Value, int32 Size)
{
    auto* T = WidgetTree->ConstructWidget<UTextBlock>(); T->SetText(FText::FromString(Value));
    auto Font = T->GetFont(); Font.Size = Size; T->SetFont(Font); T->SetAutoWrapText(true); T->SetColorAndOpacity(Session()->Preferences->Theme == TEXT("light") ? FSlateColor(FLinearColor(0.05, 0.07, 0.1)) : FSlateColor(FLinearColor::White)); Panel->AddChild(T); return T;
}
UButton* UExplorerAppWidget::Button(const FString& Value)
{
    auto* B = WidgetTree->ConstructWidget<UButton>(); auto* T = WidgetTree->ConstructWidget<UTextBlock>(); T->SetText(FText::FromString(Value));
    auto Font = T->GetFont(); Font.Size = 20; T->SetFont(Font); B->AddChild(T); Panel->AddChild(B); return B;
}
void UExplorerAppWidget::RebuildScreen(EExplorerScreen Screen)
{
    if (!Panel)
    {
        auto* Canvas = WidgetTree->ConstructWidget<UCanvasPanel>(); WidgetTree->RootWidget = Canvas;
        RootBorder = WidgetTree->ConstructWidget<UBorder>(); RootSlot = Canvas->AddChildToCanvas(RootBorder);
        Panel = WidgetTree->ConstructWidget<UVerticalBox>(); RootBorder->SetContent(Panel);
    }
    Panel->ClearChildren(); auto* Slot = RootSlot.Get();
    Slot->SetAutoSize(true); Slot->SetAnchors(FAnchors(0.5, 0.5)); Slot->SetAlignment(FVector2D(0.5, 0.5)); Slot->SetPosition(FVector2D::ZeroVector);
    RootBorder->SetPadding(FMargin(28)); RootBorder->SetBrushColor(Session()->Preferences->Theme == TEXT("light") ? FLinearColor(0.93, 0.94, 0.95, 0.95) : FLinearColor(0.025, 0.035, 0.05, 0.95));
    Status = nullptr; Query = nullptr; Results = nullptr;
    // Dynamic delegates require literal member functions; the following calls keep bindings explicit.
    switch (Screen)
    {
    case EExplorerScreen::Home:
        Text(TEXT("CITY EXPLORER"), 36); Text(TEXT("Find your place in Barcelona."));
        Button(TEXT("Explore"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::ExploreMode); break;
    case EExplorerScreen::City:
        Text(TEXT("Choose a city"), 30); Button(TEXT("Barcelona · Spain"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::ChooseCity);
        Button(TEXT("Back"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::Home); break;
    case EExplorerScreen::Location:
        Text(TEXT("Where would you like to begin?"), 28); Text(TEXT("Search recorded Barcelona places and addresses"));
        Query = WidgetTree->ConstructWidget<UEditableTextBox>(); Query->SetHintText(FText::FromString(TEXT("Address, landmark, hotel or restaurant"))); Panel->AddChild(Query);
        Button(TEXT("Search"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::Search);
        Results = WidgetTree->ConstructWidget<UComboBoxString>(); Panel->AddChild(Results);
        Button(TEXT("Choose selected location"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::ChoosePlace);
        Status = Text(TEXT("Offline city data · © OpenStreetMap contributors"), 16);
        Button(TEXT("Back"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::ExploreMode); break;
    case EExplorerScreen::Vehicle:
        Text(TEXT("Choose your car"), 30); Text(TEXT("City Touring Car"));
        Button(TEXT("Start exploring"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::StartDriving);
        Button(TEXT("Back"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::ChangeLocation); Status = Text(TEXT("")); break;
    case EExplorerScreen::Exploring:
        Slot->SetAnchors(FAnchors(0, 0)); Slot->SetAlignment(FVector2D::ZeroVector); Slot->SetPosition(FVector2D(20, 20));
        Text(TEXT("Barcelona"), 24); Status = Text(TEXT("0 km/h"));
        Button(TEXT("Pause"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::Pause); break;
    case EExplorerScreen::Paused:
        Text(TEXT("Paused"), 30); Button(TEXT("Continue"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::Pause);
        Button(TEXT("Recover to safe road"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::Recover);
        Button(TEXT("Choose new location"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::ChangeLocation);
        Button(TEXT("Settings"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::Settings);
        Button(TEXT("Home"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::Home); break;
    case EExplorerScreen::Settings:
        Text(TEXT("Settings"), 30); Text(TEXT("W/↑ Drive · S/↓/Space Brake · A/D/←/→ Steer\nC Camera · R Recover · P/Escape Pause"), 16);
        Button(TEXT("Toggle sound"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::ToggleSound);
        Button(TEXT("Toggle 30/60 FPS"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::ToggleFrameCap);
        Button(TEXT("Change appearance"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::ToggleTheme);
        Text(TEXT("© OpenStreetMap contributors · ODbL\nAjuntament de Barcelona / Open Data BCN · CC BY\nTerrain: ICGC MET5 · CC BY 4.0"), 14);
        Button(TEXT("Continue"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::Pause); Status = Text(TEXT("")); break;
    }
}
void UExplorerAppWidget::Refresh()
{
    if (Session()->Screen == EExplorerScreen::Exploring && Status)
        if (auto* Car = Cast<AExplorerVehicle>(GetOwningPlayerPawn())) Status->SetText(FText::FromString(FString::Printf(TEXT("%.0f km/h"), FMath::Abs(Car->Movement->Handling.Speed) * 3.6)));
}
void UExplorerAppWidget::ExploreMode() { Session()->SetScreen(EExplorerScreen::City); }
void UExplorerAppWidget::ChooseCity() { Session()->SetScreen(EExplorerScreen::Location); }
void UExplorerAppWidget::Search()
{
    if (!Query || !Results) return; Results->ClearOptions();
    Status->SetText(FText::FromString(TEXT("Searching...")));
    GetGameInstance()->GetSubsystem<UExplorerPlaceSearchSubsystem>()->Search(Query->GetText().ToString());
}
void UExplorerAppWidget::ReceiveResults(const TArray<FExplorerPlace>& Values)
{
    if (!Results || !Status || Session()->Screen != EExplorerScreen::Location) return;
    Results->ClearOptions(); Matches = Values;
    for (int32 I = 0; I < Matches.Num(); ++I) Results->AddOption(FString::Printf(TEXT("%d · %s"), I + 1, *Matches[I].Name));
    if (!Matches.IsEmpty()) Results->SetSelectedIndex(0);
    Status->SetText(FText::FromString(Matches.IsEmpty() ? TEXT("No recorded matches. Refine your search.") : TEXT("Choose a match from the list.")));
}
void UExplorerAppWidget::ChoosePlace()
{
    if (!Results) return; const int32 Index = Results->GetSelectedIndex(); if (!Matches.IsValidIndex(Index)) return;
    GetGameInstance()->GetSubsystem<UExplorerPlaceSearchSubsystem>()->Resolve(Matches[Index]);
}
void UExplorerAppWidget::ReceiveResolved(FExplorerPlace Place)
{
    if (Session()->Screen != EExplorerScreen::Location || !Status) return;
    FVector P; FRotator R; auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>();
    if (!Map->SafeSpawn(Place.Point, P, R)) { Status->SetText(FText::FromString(TEXT("Unable to start here. Choose another location."))); return; }
    SelectedPoint = Place.Point; bSelected = true; Session()->SetScreen(EExplorerScreen::Vehicle);
}
void UExplorerAppWidget::StartDriving()
{
    if (!bSelected || !Cast<AExplorerPlayerController>(GetOwningPlayer())->BeginExplore(SelectedPoint)) if (Status) Status->SetText(FText::FromString(TEXT("Unable to start here.")));
}
void UExplorerAppWidget::Pause() { Cast<AExplorerPlayerController>(GetOwningPlayer())->TogglePause(); }
void UExplorerAppWidget::Home() { Cast<AExplorerPlayerController>(GetOwningPlayer())->ShowHome(); }
void UExplorerAppWidget::Settings() { Session()->SetScreen(EExplorerScreen::Settings); }
void UExplorerAppWidget::ChangeLocation() { Session()->SetScreen(EExplorerScreen::Location); }
void UExplorerAppWidget::Recover() { Cast<AExplorerPlayerController>(GetOwningPlayer())->RecoverVehicle(); }
void UExplorerAppWidget::ToggleSound() { auto* S = Session(); S->Preferences->bMuted = !S->Preferences->bMuted; S->SavePreferences(); }
void UExplorerAppWidget::ToggleFrameCap()
{
    auto* S = Session(); S->Preferences->FrameCap = S->Preferences->FrameCap == 30 ? 60 : 30;
    if (GEngine) GEngine->SetMaxFPS(S->Preferences->FrameCap); S->SavePreferences();
}
void UExplorerAppWidget::ToggleTheme()
{
    auto* S = Session(); S->Preferences->Theme = S->Preferences->Theme == TEXT("dark") ? TEXT("light") : TEXT("dark"); S->SavePreferences(); RebuildScreen(S->Screen);
}

void UExplorerAppWidget::ReceiveError(FString Message)
{
    if (Status) Status->SetText(FText::FromString(Message));
}
