# AdvancedSpawnPoints
This is a Mutator for Unreal Tournament (1999) that improves the logic of player spawn points and customization options to avoid respawns in front of enemy players.

**Installation**
Add ServerPackages=AdvancedSpawnPoints in your main Server UnrealTournament.ini

Add AdvancedSpawnPoints.ASPMutator to your mutator list 

Default and recommended mutator settings are:

```
[AdvancedSpawnPoints.ASPMutator]
bEnabled=True
bDebugMode=False
MinSpawnDistance=1200
MinSpawnZVariance=-190
SpawnLOSPenalty=2
DefaultSpawnWeight=2000
bAdvancedSpawns=True
bSafeSpawns=True
SpawnRecentPenalty=0.5
SpawnNearLastPenalty=1.5
SpawnRelevantDistance=4000
```

The code for this mutator is based on Random Spawn Location by MrLoathsome and UTPureDP custom spawn algorithm by Max]I[muS-X
