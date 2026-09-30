using UnrealBuildTool;
public class CityExplorerTarget : TargetRules
{
    public CityExplorerTarget(TargetInfo Target) : base(Target)
    {
        Type = TargetType.Game;
        DefaultBuildSettings = BuildSettingsVersion.V5;
        IncludeOrderVersion = EngineIncludeOrderVersion.Unreal5_5;
        ExtraModuleNames.Add("CityExplorer");
    }
}
