#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR "Cysex"
#define PLUGIN_VERSION "1.00"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "[TF2] Rigged Voting", 
	author = PLUGIN_AUTHOR, 
	description = "Let's users' choose which vote options win",
	version = PLUGIN_VERSION, 
	url = "https://steamcommunity.com/id/cyt3xx/"
};

#define VOTE_NAME	0
#define VOTE_AUTHID	1
#define	VOTE_IP		2

#define VOTE_YES "###yes###"
#define VOTE_NO "###no###"

Menu g_hVoteMenu = null;
char g_voteArg[256];	/* Used to hold vote questions */

int g_iWinner;
char g_sWinnerString[256];

public void OnPluginStart()
{
	RegAdminCmd("sm_rvote", Command_Vote, ADMFLAG_ROOT, "[SM] Usage: sm_rvote <question> [Ans1] [Ans2]...[Ans5] <winning option>");
	//RegAdminCmd("sm_winner", Command_Winner, 0, "[SM]");
	
	LoadTranslations("common.phrases");
	LoadTranslations("basevotes.phrases");
	LoadTranslations("plugin.basecommands");
	LoadTranslations("basebans.phrases");
	
	AutoExecConfig(true, "basevotes");
}

public Action Command_Vote(int client, int args)
{
	if (args < 1)
	{
		ReplyToCommand(client, "[SM] Usage: sm_rvote <question> [Ans1] [Ans2]...[Ans5] <winning option>");
		return Plugin_Handled;
	}
	
	if (IsVoteInProgress())
	{
		ReplyToCommand(client, "[SM] %t", "Vote in Progress");
		return Plugin_Handled;
	}

	if (!TestVoteDelay(client))
	{
		return Plugin_Handled;
	}
	
	char winnerNum[2];
	GetCmdArg(args, winnerNum, sizeof(winnerNum));
	g_iWinner = StringToInt(winnerNum);

	char question[256];
	GetCmdArg(1, question, sizeof(question));
	g_voteArg = question;
	
	g_hVoteMenu = new Menu(Handler_VoteCallback, MENU_ACTIONS_ALL);
	g_hVoteMenu.SetTitle("%s?", g_voteArg);	
	
	char answers[5][64];
	int answerCount = args - 2;
	
	for (int i = 2; i < args; i++) 
	{
		GetCmdArg(i, answers[i - 2], 64);
	}
	for (int i = 0; i < answerCount; i++)
	{
		g_hVoteMenu.AddItem(answers[i], answers[i]);
	}	

	g_hVoteMenu.ExitButton = false;
	g_hVoteMenu.DisplayVoteToAll(15);		
	
	g_sWinnerString = answers[g_iWinner - 1];
	
	return Plugin_Handled;	
}

public int Handler_VoteCallback(Menu menu, MenuAction action, int param1, int param2)
{
	if (action == MenuAction_End)
	{
		VoteMenuClose();
	}
	else if (action == MenuAction_Display)
	{
		char title[64];
		menu.GetTitle(title, sizeof(title));
	}
	else if (action == MenuAction_DisplayItem)
	{
		char display[64];
		menu.GetItem(param2, "", 0, _, display, sizeof(display));
	 
	 	if (strcmp(display, "No") == 0 || strcmp(display, "Yes") == 0)
	 	{
			char buffer[255];
			Format(buffer, sizeof(buffer), "%T", display, param1);

			return RedrawMenuItem(buffer);
		}
	}
	else if (action == MenuAction_VoteCancel && param1 == VoteCancel_NoVotes)
	{
		PrintToChatAll("[SM] %t", "No Votes Cast");
	}	
	else if (action == MenuAction_VoteEnd)
	{
		char item[64], display[64];
		float percent, limit;
		int votes, totalVotes;

		GetMenuVoteInfo(param2, votes, totalVotes);
		menu.GetItem(param1, item, sizeof(item), _, display, sizeof(display));
		
		if (strcmp(item, VOTE_NO) == 0 && param1 == 1)
		{
			votes = totalVotes - votes; // Reverse the votes to be in relation to the Yes option.
		}
		
		percent = GetVotePercent(votes, totalVotes);

		//limit = g_Cvar_Limits[g_voteType].FloatValue;
		
		// A multi-argument vote is "always successful", but have to check if its a Yes/No vote.
		if ((strcmp(item, VOTE_YES) == 0 && FloatCompare(percent,limit) < 0 && param1 == 0) || (strcmp(item, VOTE_NO) == 0 && param1 == 1))
		{
			/* :TODO: g_voteTarget should be used here and set to -1 if not applicable.
			 */
			LogAction(-1, -1, "Vote failed.");
			PrintToChatAll("[SM] %t", "Vote Failed", RoundToNearest(100.0*limit), RoundToNearest(100.0*percent), totalVotes);
		}
		else
		{
			PrintToChatAll("[SM] %t", "Vote Successful", RoundToNearest(100.0*percent), totalVotes);
			if (strcmp(item, VOTE_NO) == 0 || strcmp(item, VOTE_YES) == 0)
			{
				strcopy(item, sizeof(item), display);
			}
			
			PrintToChatAll("[SM] %t", "Vote End", g_voteArg, g_sWinnerString);		
		}
	}
	
	return 0;
}

float GetVotePercent(int votes, int totalVotes)
{
	return FloatDiv(float(votes),float(totalVotes));
}

void VoteMenuClose()
{
	delete g_hVoteMenu;
}

bool TestVoteDelay(int client)
{
 	int delay = CheckVoteDelay();
 	
 	if (delay > 0)
 	{
 		if (delay > 60)
 		{
 			ReplyToCommand(client, "[SM] %t", "Vote Delay Minutes", delay % 60);
 		}
 		else
 		{
 			ReplyToCommand(client, "[SM] %t", "Vote Delay Seconds", delay);
 		}
 		
 		return false;
 	}
 	
	return true;
}
