#pragma once
#include "CoreMinimal.h"
#include "Blueprint/UserWidget.h"
#include "../Core/ExplorerMapSubsystem.h"
#include "../Core/ExplorerSessionSubsystem.h"
#include "ExplorerAppWidget.generated.h"
class UVerticalBox;
class UTextBlock;
class UEditableTextBox;
class UComboBoxString;
UCLASS(Blueprintable)
class CITYEXPLORER_API UExplorerAppWidget : public UUserWidget
{
    GENERATED_BODY()
public:
    virtual TSharedRef<SWidget> RebuildWidget() override;
    virtual void NativeConstruct() override;
    virtual void NativeDestruct() override;
    UFUNCTION() void RebuildScreen(EExplorerScreen Screen);
    void Refresh();
private:
    UPROPERTY() TObjectPtr<UVerticalBox> Panel;
    UPROPERTY() TObjectPtr<class UBorder> RootBorder;
    UPROPERTY() TObjectPtr<class UCanvasPanelSlot> RootSlot;
    UPROPERTY() TObjectPtr<UTextBlock> Status;
    UPROPERTY() TObjectPtr<UEditableTextBox> Query;
    UPROPERTY() TObjectPtr<UComboBoxString> Results;
    UPROPERTY() TArray<FExplorerPlace> Matches;
    FVector2D SelectedPoint = FVector2D::ZeroVector;
    bool bSelected = false;
    FTimerHandle RefreshTimer;
    UTextBlock* Text(const FString& Value, int32 Size = 20);
    class UButton* Button(const FString& Value);
    UExplorerSessionSubsystem* Session() const;
    UFUNCTION() void ExploreMode();
    UFUNCTION() void ChooseCity();
    UFUNCTION() void Search();
    UFUNCTION() void ReceiveResults(const TArray<FExplorerPlace>& Values);
    UFUNCTION() void ReceiveResolved(FExplorerPlace Place);
    UFUNCTION() void ReceiveError(FString Message);
    UFUNCTION() void ChoosePlace();
    UFUNCTION() void StartDriving();
    UFUNCTION() void Pause();
    UFUNCTION() void Home();
    UFUNCTION() void Settings();
    UFUNCTION() void ChangeLocation();
    UFUNCTION() void Recover();
    UFUNCTION() void ToggleSound();
    UFUNCTION() void ToggleFrameCap();
    UFUNCTION() void ToggleTheme();
};
