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
#include "Misc/CommandLine.h"
#include "Misc/Parse.h"
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
    GetWorld()->GetTimerManager().SetTimer(RefreshTimer, this, &UExplorerAppWidget::Refresh, 0.1, true);
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
    auto Font = T->GetFont(); Font.Size = 20; T->SetFont(Font); T->SetVisibility(ESlateVisibility::HitTestInvisible); B->SetVisibility(ESlateVisibility::Visible); B->SetIsEnabled(true);
    B->AddChild(T); Panel->AddChild(B); if (!FirstButton) FirstButton = B; return B;
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
    Status = nullptr; Query = nullptr; Results = nullptr; NextButton = nullptr; FirstButton = nullptr;
    UE_LOG(LogTemp, Display, TEXT("CityExplorer UI screen=%d"), int32(Screen));
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
        Query = WidgetTree->ConstructWidget<UEditableTextBox>(); Query->SetHintText(FText::FromString(TEXT("Address, landmark, hotel or restaurant"))); Query->SetForegroundColor(FLinearColor::Black); Query->SetClearKeyboardFocusOnCommit(false); Query->OnTextCommitted.AddDynamic(this, &UExplorerAppWidget::QueryCommitted); Query->OnTextChanged.AddDynamic(this, &UExplorerAppWidget::QueryChanged); Panel->AddChild(Query);
        Button(TEXT("Search"))->OnClicked.AddDynamic(this, &UExplorerAppWidget::Search);
        Results = WidgetTree->ConstructWidget<UComboBoxString>(); Results->OnGenerateWidgetEvent.BindDynamic(this, &UExplorerAppWidget::GenerateResultWidget); Results->SetContentPadding(FMargin(8, 8)); Results->SetEnableGamepadNavigationMode(false); Results->OnSelectionChanged.AddDynamic(this, &UExplorerAppWidget::ResultChanged); Panel->AddChild(Results);
        NextButton = Button(TEXT("Next")); NextButton->OnClicked.AddDynamic(this, &UExplorerAppWidget::ChoosePlace); NextButton->SetIsEnabled(false); bSelected = false; Matches.Reset();
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
        if (auto* Car = Cast<AExplorerVehicle>(GetOwningPlayerPawn())) Status->SetText(FText::FromString(FString::Printf(TEXT("%.0f km/h"), FMath::Abs(Car->DrivePhysics->GetForwardSpeed()) * 0.036)));
}
void UExplorerAppWidget::ExploreMode() { UE_LOG(LogTemp, Display, TEXT("CityExplorer UI Explore clicked")); Session()->SetScreen(EExplorerScreen::City); }
void UExplorerAppWidget::ChooseCity() { Session()->SetScreen(EExplorerScreen::Location); }
void UExplorerAppWidget::Search()
{
    if (!Query || !Results) return;
    const FString Clean = Query->GetText().ToString().TrimStartAndEnd();
    UE_LOG(LogTemp, Display, TEXT("CityExplorer UI search submitted length=%d"), Clean.Len());
    if (Clean.Len() < 2) { Status->SetText(FText::FromString(TEXT("Enter at least two characters."))); Query->SetUserFocus(GetOwningPlayer()); return; }
    Results->ClearOptions(); Matches.Reset(); NextButton->SetIsEnabled(false); bSelected = false;
    Status->SetText(FText::FromString(TEXT("Searching...")));
    GetGameInstance()->GetSubsystem<UExplorerPlaceSearchSubsystem>()->Search(Query->GetText().ToString());
}
void UExplorerAppWidget::ReceiveResults(const TArray<FExplorerPlace>& Values)
{
    if (!Results || !Status || Session()->Screen != EExplorerScreen::Location) return;
    Results->ClearOptions(); Matches = Values;
    for (int32 I = 0; I < Matches.Num(); ++I) Results->AddOption(FString::Printf(TEXT("%d · %s"), I + 1, *Matches[I].Name));
    UE_LOG(LogTemp, Display, TEXT("CityExplorer UI results displayed count=%d"), Matches.Num());
    if (!Matches.IsEmpty()) Results->SetUserFocus(GetOwningPlayer());
    Status->SetText(FText::FromString(Matches.IsEmpty() ? TEXT("No recorded matches. Refine your search.") : TEXT("Choose a match from the list.")));
}
void UExplorerAppWidget::ChoosePlace()
{
    if (!Results) return; const int32 Index = Results->GetSelectedIndex();
    if (!Matches.IsValidIndex(Index)) { if (Status) Status->SetText(FText::FromString(TEXT("Select a search result first."))); return; }
    UE_LOG(LogTemp, Display, TEXT("CityExplorer UI resolving selected index=%d"), Index); NextButton->SetIsEnabled(false);
    GetGameInstance()->GetSubsystem<UExplorerPlaceSearchSubsystem>()->Resolve(Matches[Index]);
}
void UExplorerAppWidget::ReceiveResolved(FExplorerPlace Place)
{
    if (Session()->Screen != EExplorerScreen::Location || !Status) return;
    FVector P; FRotator R; auto* Map = GetGameInstance()->GetSubsystem<UExplorerMapSubsystem>();
    if (!Map->SafeSpawn(Place.Point, P, R)) { NextButton->SetIsEnabled(true); Status->SetText(FText::FromString(TEXT("Unable to start here. Choose another location."))); return; }
    SelectedPoint = Place.Point; bSelected = true;
    UE_LOG(LogTemp, Display, TEXT("CityExplorer UI selected location stored; safe spawn validated"));
    if (FParse::Param(FCommandLine::Get(), TEXT("CityExplorerInputTrace"))) UE_LOG(LogTemp, Display, TEXT("CityExplorer UI selected point=%s"), *SelectedPoint.ToString());
    Session()->SetScreen(EExplorerScreen::Vehicle);
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
void UExplorerAppWidget::ToggleSound() { auto* S = Session(); S->Preferences->bMuted = !S->Preferences->bMuted; S->ApplyAudioPreference(); S->SavePreferences(); if (Status) Status->SetText(FText::FromString(S->Preferences->bMuted ? TEXT("Sound off") : TEXT("Sound on"))); }
void UExplorerAppWidget::ToggleFrameCap()
{
    auto* S = Session(); S->Preferences->FrameCap = S->Preferences->FrameCap == 30 ? 60 : 30;
    if (GEngine) GEngine->SetMaxFPS(S->Preferences->FrameCap); S->SavePreferences(); if (Status) Status->SetText(FText::FromString(FString::Printf(TEXT("Frame limit: %d FPS"), S->Preferences->FrameCap)));
}
void UExplorerAppWidget::ToggleTheme()
{
    auto* S = Session(); S->Preferences->Theme = S->Preferences->Theme == TEXT("dark") ? TEXT("light") : TEXT("dark"); S->SavePreferences(); RebuildScreen(S->Screen); if (auto* Focus = GetFocusTarget()) { Focus->TakeWidget(); Focus->SetUserFocus(GetOwningPlayer()); }
}

void UExplorerAppWidget::ReceiveError(FString Message)
{
    if (Status) Status->SetText(FText::FromString(Message));
}

UWidget* UExplorerAppWidget::GetFocusTarget() const { return Query ? static_cast<UWidget*>(Query) : static_cast<UWidget*>(FirstButton); }
void UExplorerAppWidget::QueryCommitted(const FText&, ETextCommit::Type Method) { if (Method == ETextCommit::OnEnter) Search(); }
void UExplorerAppWidget::QueryChanged(const FText&)
{
    if (NextButton) NextButton->SetIsEnabled(false);
    bSelected = false; Matches.Reset(); if (Results) Results->ClearOptions();
    GetGameInstance()->GetSubsystem<UExplorerPlaceSearchSubsystem>()->InvalidateSearch();
}
void UExplorerAppWidget::ResultChanged(FString, ESelectInfo::Type)
{
    const bool Valid = Results && Matches.IsValidIndex(Results->GetSelectedIndex());
    if (NextButton) NextButton->SetIsEnabled(Valid);
    if (Valid)
    {
        // The combo's key reply restores focus while closing its popup. Move to
        // Next after Slate finishes that reply, including while the world is paused.
        const TWeakObjectPtr<UExplorerAppWidget> WeakThis(this);
        TakeWidget()->RegisterActiveTimer(0.f, FWidgetActiveTimerDelegate::CreateLambda([WeakThis](double, float)
        {
            if (auto* Self = WeakThis.Get()) if (Self->NextButton && Self->Session()->Screen == EExplorerScreen::Location && Self->NextButton->GetIsEnabled()) Self->NextButton->SetUserFocus(Self->GetOwningPlayer());
            return EActiveTimerReturnType::Stop;
        }));
    }
    UE_LOG(LogTemp, Display, TEXT("CityExplorer UI result selected index=%d next=%d"), Results ? Results->GetSelectedIndex() : INDEX_NONE, Valid);
}
FReply UExplorerAppWidget::NativeOnPreviewMouseButtonDown(const FGeometry& Geometry, const FPointerEvent& Event)
{
    if (FParse::Param(FCommandLine::Get(), TEXT("CityExplorerInputTrace"))) UE_LOG(LogTemp, Display, TEXT("CityExplorer UI pointer screen=%s local=%s"), *Event.GetScreenSpacePosition().ToString(), *Geometry.AbsoluteToLocal(Event.GetScreenSpacePosition()).ToString());
    return Super::NativeOnPreviewMouseButtonDown(Geometry, Event);
}
FReply UExplorerAppWidget::NativeOnKeyDown(const FGeometry& Geometry, const FKeyEvent& Event)
{
    if ((Event.GetKey() == EKeys::Escape || Event.GetKey() == EKeys::P) && (Session()->Screen == EExplorerScreen::Paused || Session()->Screen == EExplorerScreen::Settings)) { Pause(); return FReply::Handled(); }
    return Super::NativeOnKeyDown(Geometry, Event);
}

UWidget* UExplorerAppWidget::GenerateResultWidget(FString Item)
{
    auto* Label = WidgetTree->ConstructWidget<UTextBlock>();
    Label->SetText(FText::FromString(Item.IsEmpty() ? TEXT("Select a street or place...") : Item));
    Label->SetColorAndOpacity(FSlateColor(FLinearColor::Black));
    Label->SetVisibility(ESlateVisibility::HitTestInvisible);
    auto Font = Label->GetFont(); Font.Size = 18; Label->SetFont(Font);
    auto* Row = WidgetTree->ConstructWidget<UBorder>();
    Row->SetBrushColor(FLinearColor(0.9f, 0.9f, 0.9f)); Row->SetPadding(FMargin(4));
    Row->SetContent(Label); Row->SetVisibility(ESlateVisibility::HitTestInvisible);
    return Row;
}
