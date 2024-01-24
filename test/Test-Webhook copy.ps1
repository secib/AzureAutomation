$automationAccount = "AdministrativeTask"
$resourceGroup = "Automation"
$webhookURI = "https://0101fce2-c71c-45c7-8b8f-59e626f6f35a.webhook.fc.azure-automation.net/webhooks?token=cofFVZipvIol4OHrF9y%2f7klCkZaQgX9camMZ7wkM3ho%3d"
$body = @"
{
    "subscriptionId": "8401406c-b573-4533-8d77-df8803de5153",
    "notificationId": 1,
    "id": "1e1dad80-a40f-4c6e-ae8a-e1e41b390216",
    "eventType": "git.push",
    "publisherId": "tfs",
    "message": {
      "text": "Hervé SCLAVON pushed updates to AzDeploymentToolKitTest:main\r\n(https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/#version=GBmain)",
      "html": "Herv&#233; SCLAVON pushed updates to <a href=\"https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/\">AzDeploymentToolKitTest</a>:<a href=\"https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/#version=GBmain\">main</a>",
      "markdown": "Hervé SCLAVON pushed updates to [AzDeploymentToolKitTest](https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/):[main](https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/#version=GBmain)"
    },
    "detailedMessage": {
      "text": "Hervé SCLAVON pushed a commit to AzDeploymentToolKitTest:main\r\n - ajout commentaire 9f961760 (https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/commit/9f9617607c680eae5395412f9dcbf5dc185c3913)",
      "html": "Herv&#233; SCLAVON pushed a commit to <a href=\"https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/\">AzDeploymentToolKitTest</a>:<a href=\"https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/#version=GBmain\">main</a>\r\n<ul>\r\n<li>ajout commentaire <a href=\"https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/commit/9f9617607c680eae5395412f9dcbf5dc185c3913\">9f961760</a></li>\r\n</ul>",
      "markdown": "Hervé SCLAVON pushed a commit to [AzDeploymentToolKitTest](https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/):[main](https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/#version=GBmain)\r\n* ajout commentaire [9f961760](https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest/commit/9f9617607c680eae5395412f9dcbf5dc185c3913)"
    },
    "resource": {
      "commits": [
        {
          "commitId": "9f9617607c680eae5395412f9dcbf5dc185c3913",
          "author": {
            "name": "Hervé SCLAVON",
            "email": "herve.sclavon@septeo.com",
            "date": "2024-01-18T20:26:39Z"
          },
          "committer": {
            "name": "Hervé SCLAVON",
            "email": "herve.sclavon@septeo.com",
            "date": "2024-01-18T20:26:39Z"
          },
          "comment": "ajout commentaire",
          "url": "https://dev.azure.com/AzDeploymentToolkitTestProject/_apis/git/repositories/2fc13ae2-c67a-4aac-b9c2-f9db228d1eb5/commits/9f9617607c680eae5395412f9dcbf5dc185c3913"
        }
      ],
      "refUpdates": [
        {
          "name": "refs/heads/main",
          "oldObjectId": "143354fc8f1329f364400464f08046c3e74a467a",
          "newObjectId": "9f9617607c680eae5395412f9dcbf5dc185c3913"
        }
      ],
      "repository": {
        "id": "2fc13ae2-c67a-4aac-b9c2-f9db228d1eb5",
        "name": "AzDeploymentToolKitTest",
        "url": "https://dev.azure.com/AzDeploymentToolkitTestProject/_apis/git/repositories/2fc13ae2-c67a-4aac-b9c2-f9db228d1eb5",
        "project": {
          "id": "fe9774a6-af7b-43d4-a0e6-f85cf0139f3b",
          "name": "AzDeploymentToolKitTest",
          "url": "https://dev.azure.com/AzDeploymentToolkitTestProject/_apis/projects/fe9774a6-af7b-43d4-a0e6-f85cf0139f3b",
          "state": "wellFormed",
          "visibility": "unchanged",
          "lastUpdateTime": "0001-01-01T00:00:00"
        },
        "defaultBranch": "refs/heads/main",
        "remoteUrl": "https://dev.azure.com/AzDeploymentToolkitTestProject/AzDeploymentToolKitTest/_git/AzDeploymentToolKitTest"
      },
      "pushedBy": {
        "displayName": "Hervé SCLAVON",
        "url": "https://spsprodneu1.vssps.visualstudio.com/Ad96ba4f3-f9b2-4375-b39c-e2749c12e5d5/_apis/Identities/f19ce07c-8497-6098-b23e-89142ea65e0b",
        "_links": {
          "avatar": {
            "href": "https://dev.azure.com/AzDeploymentToolkitTestProject/_apis/GraphProfile/MemberAvatars/aad.ZjE5Y2UwN2MtODQ5Ny03MDk4LWIyM2UtODkxNDJlYTY1ZTBi"
          }
        },
        "id": "f19ce07c-8497-6098-b23e-89142ea65e0b",
        "uniqueName": "herve.sclavon@septeo.com",
        "imageUrl": "https://dev.azure.com/AzDeploymentToolkitTestProject/_api/_common/identityImage?id=f19ce07c-8497-6098-b23e-89142ea65e0b",
        "descriptor": "aad.ZjE5Y2UwN2MtODQ5Ny03MDk4LWIyM2UtODkxNDJlYTY1ZTBi"
      },
      "pushId": 6,
      "date": "2024-01-18T20:26:56.6363943Z",
      "url": "https://dev.azure.com/AzDeploymentToolkitTestProject/_apis/git/repositories/2fc13ae2-c67a-4aac-b9c2-f9db228d1eb5/pushes/6",
      "_links": {
        "self": {
          "href": "https://dev.azure.com/AzDeploymentToolkitTestProject/_apis/git/repositories/2fc13ae2-c67a-4aac-b9c2-f9db228d1eb5/pushes/6"
        },
        "repository": {
          "href": "https://dev.azure.com/AzDeploymentToolkitTestProject/fe9774a6-af7b-43d4-a0e6-f85cf0139f3b/_apis/git/repositories/2fc13ae2-c67a-4aac-b9c2-f9db228d1eb5"
        },
        "commits": {
          "href": "https://dev.azure.com/AzDeploymentToolkitTestProject/_apis/git/repositories/2fc13ae2-c67a-4aac-b9c2-f9db228d1eb5/pushes/6/commits"
        },
        "pusher": {
          "href": "https://spsprodneu1.vssps.visualstudio.com/Ad96ba4f3-f9b2-4375-b39c-e2749c12e5d5/_apis/Identities/f19ce07c-8497-6098-b23e-89142ea65e0b"
        },
        "refs": {
          "href": "https://dev.azure.com/AzDeploymentToolkitTestProject/fe9774a6-af7b-43d4-a0e6-f85cf0139f3b/_apis/git/repositories/2fc13ae2-c67a-4aac-b9c2-f9db228d1eb5/refs/heads/main"
        }
      }
    },
    "resourceVersion": "1.0",
    "resourceContainers": {
      "collection": {
        "id": "e943cfc2-0c28-4e54-80b5-4d4f1f3f21cc",
        "baseUrl": "https://dev.azure.com/AzDeploymentToolkitTestProject/"
      },
      "account": {
        "id": "d96ba4f3-f9b2-4375-b39c-e2749c12e5d5",
        "baseUrl": "https://dev.azure.com/AzDeploymentToolkitTestProject/"
      },
      "project": {
        "id": "fe9774a6-af7b-43d4-a0e6-f85cf0139f3b",
        "baseUrl": "https://dev.azure.com/AzDeploymentToolkitTestProject/"
      }
    },
    "createdDate": "2024-01-18T20:27:03.5095237Z"
  }  
"@

$responseFile = Invoke-WebRequest -Method Post -Uri $webhookURI -Body $body -UseBasicParsing
$responseFile

#isolate job ID
$jobid = (ConvertFrom-Json ($responseFile.Content)).jobids[0]

# Get output
Get-AzAutomationJobOutput `
    -AutomationAccountName $automationAccount `
    -Id $jobid `
    -ResourceGroupName $resourceGroup `
    -Stream Output

Get-AzAutomationJob `
    -AutomationAccountName $automationAccount `
    -Id $jobid `
    -ResourceGroupName $resourceGroup `
