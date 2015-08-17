Wahl Network Scripts Repository
================

This repository contains a number of scripts that I have written or enhanced to make day-to-day life easier for administrators, engineers, and architects. These are provided for free to the community under an [Apache License v2](http://www.apache.org/licenses/LICENSE-2.0.html). I also have a number of [PowerShell related blog posts](http://wahlnetwork.com/?s=powershell) at Wahl Network for those interested.

# Installation

The code assumes that you've already deployed at least one Brik into your environment and have completed the initial configuration process. Make sure you have PowerShell version 4 or higher installed on your workstation.

1. Download the contents of this repository to your workstation.
2. Copy over the scripts found in any of the directories (such as `Slack`, `VMware NSX`, `VMware vSphere`, or others) into th e `WahlNetwork` folder.
2. Copy the contents of the `WahlNetwork` folder onto your workstation into the path `$Home\Documents\WindowsPowerShell\Modules\`

Launch PowerShell and make sure `Set-ExecutionPolicy` is set to `RemoteSigned` or `Bypass`. To load the module, use `Import-Module Rubrik`.

# Usage Instructions

To see all of the imported commands, use `Get-Command -Module WahlNetwork`.

# Future

Any PowerShell related scripts will be added here over time as I write them. There is no grand scheme here.

# Contribution

Create a fork of the project into your own reposity. Make all your necessary changes and create a pull request with a description on what was added or removed and details explaining the changes in lines of code. If approved, project owners will merge it.

# Licensing

Licensed under the Apache License, Version 2.0 (the “License”); you may not use this file except in compliance with the License. You may obtain a copy of the License at http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an “AS IS” BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
