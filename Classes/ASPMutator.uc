//*  Advanced Spawn Points TDM UT99 Mutator                                                                       *//
//*  Based on code from Random Spawn Location by MrLoathsome and UTPureDP custom spawn algorithm by Max]I[muS-X   *//
//*  bAdvancedSpawns helps to reduce respawn rates close to enemy players                                         *//

class ASPMutator expands Mutator config(AdvancedSpawnPoints);

var config float CollisionDist, MinSpawnDistance, MinSpawnZVariance, SpawnLOSPenalty, DefaultSpawnWeight, SpawnRelevantDistance;
var config bool bEnabled, bAdvancedSpawns, bSafeSpawns,bDebugMode;
var int NumValidSpawns;
var Vector ValidSpawns[64];
var Rotator ValidSpawnsRotation[64];
var Vector LastStartSpot;
var Vector PlayerLastStartSpot2[32];
var Vector PlayerLastStartSpot3[32];
var config float SpawnRecentPenalty;
var config float SpawnNearLastPenalty;

function PostBeginPlay()
{
	local PlayerStart PS;

    Super.PostBeginPlay();

    if (!Level.Game.IsA('TeamGamePlus')) {
        log("AdvancedSpawnPoints Mutator is designed to work only with Team DeathMatch. Exiting...");
        return;
    }

    if (!bEnabled) {
        log("AdvancedSpawnPoints Mutator is disabled. Exiting...");
        return;
    }

    foreach AllActors(class'PlayerStart', PS)
    {
        if (NumValidSpawns < 64) {
            ValidSpawns[NumValidSpawns] = PS.Location;
            ValidSpawnsRotation[NumValidSpawns] = PS.Rotation;
            NumValidSpawns++;
        }
    }

    log("AdvancedSpawnPoints Mutator initilized.");
    
    SaveConfig();
}

function ModifyPlayer(Pawn Other)
{
    local UTTeleportEffect TelEff;
    local Vector SpawnLoc;
    local Rotator SpawnRot;

    Super.ModifyPlayer(Other);

    if (bEnabled == False)
        return;

    if (Other.IsA('Bot')) // Do not modify bot spawns
        {
            log("This was a bot. Exiting...");
            return;
        }
        
    if (bAdvancedSpawns)
    {
        FindPlayerStartAdvanced(Other, SpawnLoc, SpawnRot, Other.PlayerReplicationInfo.Team);

        if (LastStartSpot == SpawnLoc) {
                FindPlayerStartAdvanced(Other, SpawnLoc, SpawnRot, Other.PlayerReplicationInfo.Team);
        }
    }
    else
    {
        SpawnLoc = ValidSpawns[Rand(NumValidSpawns)];
        SpawnRot = ValidSpawnsRotation[Rand(NumValidSpawns)];
    }

    // Destroy any existing teleport effects at the spawn location
    foreach RadiusActors(class'UTTeleportEffect', TelEff, 20, SpawnLoc)
    {
        TelEff.Destroy();
    }

    Other.SetLocation(SpawnLoc);
    Other.SetRotation(SpawnRot);
    Other.ViewRotation = SpawnRot;
    Other.ClientSetRotation(SpawnRot);

    if (bDebugMode)
    {
        Other.ClientMessage("New Advanced Spawn Point at: "@SpawnLoc);
    }
    
    Level.Game.PlayTeleportEffect(Other, True, True); // Play the teleport effect at the spawn location
}

function bool FindPlayerStartAdvanced(Pawn Player, out Vector SpawnLoc, out Rotator SpawnRot, optional byte InTeam)
{
    local byte Team;
    local bool bInvalid, bLineOfSight, bIsRelevantDist, bIsMinZVariance;
    local int i, CurrentScore, BestScore, StartScore, TeamSizes[2];
    local float CollisionDist, PlayerDist, SpawnDist, EnemyZVariance, MinEnemyDist;
    local Vector Best;
    local Pawn OtherPlayer;
    local PlayerReplicationInfo PRI;
    local int RandomIndex;

    if (Player != None && Player.PlayerReplicationInfo != None)
        Team = Player.PlayerReplicationInfo.Team;
    else
        Team = InTeam;

    if (Team == 255) Team = 0;

    CollisionDist = 2 * (Player.CollisionRadius + Player.CollisionHeight);
    BestScore = 0;
    Best = ValidSpawns[Rand(NumValidSpawns)];

    // Calculate team sizes
    for (OtherPlayer = Level.PawnList; OtherPlayer != None; OtherPlayer = OtherPlayer.NextPawn) {
        PRI = OtherPlayer.PlayerReplicationInfo;
        if (PRI != None && PRI.Team < 2) {
            TeamSizes[PRI.Team]++;
        }
    }

    if (Team == 0) StartScore = TeamSizes[1] * SpawnLOSPenalty;
    else StartScore = TeamSizes[0] * SpawnLOSPenalty;

    for (i = 0; i < NumValidSpawns; i++) {
        bInvalid = False;
        CurrentScore = StartScore;
        MinEnemyDist = 100000;

        if (Player.IsA('TournamentPlayer') && TournamentPlayer(Player).StartSpot != None) {
            if (ValidSpawns[i] == TournamentPlayer(Player).StartSpot.Location) {
                bInvalid = True;
                continue;
            } else {
                // Recent spawn penalty
                if (ValidSpawns[i] == PlayerLastStartSpot2[Player.PlayerReplicationInfo.PlayerID] || ValidSpawns[i] == PlayerLastStartSpot3[Player.PlayerReplicationInfo.PlayerID]) {
                    CurrentScore *= SpawnRecentPenalty;
                }
                
                // Spawn distance penalty
                SpawnDist = VSize(TournamentPlayer(Player).StartSpot.Location - ValidSpawns[i]);
                if (SpawnDist < SpawnRelevantDistance) {
                    CurrentScore -= (SpawnDist * SpawnNearLastPenalty);
                }
            }
        }

        for (OtherPlayer = Level.PawnList; OtherPlayer != None; OtherPlayer = OtherPlayer.NextPawn) {
            if (OtherPlayer == Player) continue;

            if (OtherPlayer.bIsPlayer && !OtherPlayer.IsA('Spectator') && OtherPlayer.Health > 0 && OtherPlayer.PlayerReplicationInfo != None) {
                PlayerDist = VSize(OtherPlayer.Location - ValidSpawns[i]);
                if (PlayerDist < CollisionDist) {
                    bInvalid = True;
                    break;
                }

                bIsRelevantDist = (PlayerDist < MinSpawnDistance);
                EnemyZVariance = OtherPlayer.Location.Z - ValidSpawns[i].Z;
                bIsMinZVariance = (EnemyZVariance <= MinSpawnZVariance);
                bLineOfSight = FastTrace(ValidSpawns[i], OtherPlayer.Location);

                if (OtherPlayer.PlayerReplicationInfo.Team != Team) {
                    if (PlayerDist < MinSpawnDistance && (!bIsMinZVariance || bLineOfSight)) {
                        bInvalid = True;
                        break;                    }
                    if (bSafeSpawns && !bIsMinZVariance && bIsRelevantDist) {
                        PlayerDist = MinSpawnDistance - PlayerDist;
                        if (bLineOfSight)
                            CurrentScore -= (PlayerDist * SpawnLOSPenalty);
                        else
                            CurrentScore -= PlayerDist;
                    }
                }
                if (PlayerDist < MinEnemyDist) MinEnemyDist = PlayerDist;
            }
        }

        if (!bInvalid) {
            if (bSafeSpawns) CurrentScore += MinEnemyDist;
            CurrentScore = Rand(Max(DefaultSpawnWeight + CurrentScore, 0));
            if (CurrentScore > BestScore) {
                BestScore = CurrentScore;
                SpawnLoc = ValidSpawns[i];
                SpawnRot = ValidSpawnsRotation[i];
                LastStartSpot = ValidSpawns[i];
            }
        } else {
            continue;
        }
    }

    if (BestScore <= 0)
        {
            RandomIndex = Rand(NumValidSpawns);
            SpawnLoc = ValidSpawns[RandomIndex];
            SpawnRot = ValidSpawnsRotation[RandomIndex];
            LastStartSpot = SpawnLoc;
            return false;
        }

    PlayerLastStartSpot3[Player.PlayerReplicationInfo.PlayerID] = PlayerLastStartSpot2[Player.PlayerReplicationInfo.PlayerID];
    PlayerLastStartSpot2[Player.PlayerReplicationInfo.PlayerID] = TournamentPlayer(Player).StartSpot.Location;

    return true;
}
                

defaultproperties
{
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
}