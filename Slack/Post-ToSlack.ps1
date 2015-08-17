#requires -Version 3

function Post-ToSlack 
{
    <#  
            .SYNOPSIS
            Sends a chat message to a Slack organization
            .DESCRIPTION
            The Post-ToSlack cmdlet is used to send a chat message to a Slack channel, group, or person.
            Slack requires a token to authenticate to an org. Either place a file named token.txt in the same directory as this cmdlet,
            or provide the token using the -token parameter. For more details on Slack tokens, use Get-Help with the -Full arg.
            .NOTES
            Written by Chris Wahl for community usage
            Twitter: @ChrisWahl
            GitHub: chriswahl
            .EXAMPLE
            Post-ToSlack -channel '#general' -message 'Hello everyone!' -botname 'The Borg'
            This will send a message to the #General channel, and the bot's name will be The Borg.
            .EXAMPLE
            Post-ToSlack -channel '#general' -message 'Hello everyone!' -token '1234567890'
            This will send a message to the #General channel using a specific token 1234567890, and the bot's name will be default (PowerShell Bot).
            .LINK
            Validate or update your Slack tokens:
            https://api.slack.com/tokens
            Create a Slack token:
            https://api.slack.com/web
            More information on Bot Users:
            https://api.slack.com/bot-users
    #>

    Param(
        [Parameter(Mandatory = $true,Position = 0,HelpMessage = 'Slack channel')]
        [ValidateNotNullorEmpty()]
        [String]$Channel,
        [Parameter(Mandatory = $true,Position = 1,HelpMessage = 'Chat message')]
        [ValidateNotNullorEmpty()]
        [String]$Message,
        [Parameter(Mandatory = $false,Position = 2,HelpMessage = 'Slack API token')]
        [ValidateNotNullorEmpty()]
        [String]$token,
        [Parameter(Mandatory = $false,Position = 3,HelpMessage = 'Optional name for the bot')]
        [String]$BotName = 'PowerShell Bot'
    )

    Process {

        # Static parameters
        if (!$token) 
        {
            $token = Get-Content -Path "$PSScriptRoot\token.txt"
        }
        $uri = 'https://slack.com/api/chat.postMessage'

        # Build the body as per https://api.slack.com/methods/chat.postMessage
        $body = @{
            token    = $token
            channel  = $Channel
            text     = $Message
            username = $BotName
            parse    = 'full'
        }

        # Call the API
        try 
        {
            Invoke-RestMethod -Uri $uri -Body $body
        }
        catch 
        {
            throw 'Unable to call the API'
        }

    } # End of process
} # End of function