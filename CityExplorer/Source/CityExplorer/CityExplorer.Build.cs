using UnrealBuildTool;
public class CityExplorer : ModuleRules
{
    public CityExplorer(ReadOnlyTargetRules Target) : base(Target)
    {
        PCHUsage = PCHUsageMode.UseExplicitOrSharedPCHs;
        PublicDependencyModuleNames.AddRange(new[] {
            "Core", "CoreUObject", "Engine", "InputCore", "EnhancedInput",
            "UMG", "HTTP", "Json", "JsonUtilities", "DeveloperSettings", "ProceduralMeshComponent", "GeometryCore", "ChaosVehicles", "PhysicsCore", "AnimGraphRuntime"
        });
        PrivateDependencyModuleNames.AddRange(new[] { "Slate", "SlateCore" });
        if (Target.bBuildEditor) PrivateDependencyModuleNames.AddRange(new[] { "UnrealEd", "Kismet", "AnimGraph", "BlueprintGraph", "ChaosVehiclesEditor" });
    }
}
