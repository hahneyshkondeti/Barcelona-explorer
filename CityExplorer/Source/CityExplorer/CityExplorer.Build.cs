using UnrealBuildTool;
public class CityExplorer : ModuleRules
{
    public CityExplorer(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PublicDependencyModuleNames.AddRange(new[] {
            "Core", "CoreUObject", "Engine", "InputCore", "EnhancedInput",
            "UMG", "HTTP", "Json", "JsonUtilities", "DeveloperSettings", "ProceduralMeshComponent", "GeometryCore"
        });
        PrivateDependencyModuleNames.AddRange(new[] { "Slate", "SlateCore" });
    }
}
