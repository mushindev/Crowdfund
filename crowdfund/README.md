### 📘 `README.md` for Crowdfunding DApp Smart Contract

````markdown
# Crowdfunding DApp Smart Contract

A decentralized crowdfunding platform built on the Stacks blockchain using Clarity smart contracts. This contract allows users to create funding campaigns, contribute STX tokens, and either collect funds or request refunds based on campaign outcomes.

---

## 📌 Features

- **Create Campaigns**: Any user can launch a new campaign with a title, description, funding goal, and deadline.
- **Contribute STX**: Users can contribute funds to active campaigns before their deadline.
- **Automatic Finalization**: Campaigns are finalized after the deadline—marked as successful if the goal is met, or failed otherwise.
- **Creator Withdrawals**: Successful campaign creators can withdraw the total raised amount.
- **Refunds**: Contributors to failed campaigns can claim full refunds.
- **Emergency Processing**: A public function to finalize and mark overdue failed campaigns as failed.

---

## 📂 Data Structures

### 🗂 Campaign
Stored in the `campaigns` map:
```clarity
{
  creator: principal,
  title: (string-ascii 100),
  description: (string-ascii 500),
  goal: uint,
  deadline: uint,
  raised: uint,
  status: uint,  ;; 1 = active, 2 = successful, 3 = failed
  created-at: uint
}
````

### 💸 Contribution

Stored in the `contributions` map:

```clarity
{
  campaign-id: uint,
  contributor: principal
} => uint
```

### 👥 Contributors List

Stored in the `campaign-contributors` map:

```clarity
uint => (list 200 principal)
```

---

## ⚙️ Public Functions

### `create-campaign(title, description, goal, duration)`

Creates a new campaign with a specified funding goal and duration (in blocks).

### `contribute(campaign-id, amount)`

Contribute STX to an active campaign.

### `finalize-campaign(campaign-id)`

Finalize a campaign once its deadline passes. Marks as successful or failed.

### `withdraw-funds(campaign-id)`

Allows the campaign creator to withdraw raised funds if the campaign is successful.

### `request-refund(campaign-id)`

Allows contributors to claim refunds from failed campaigns.

### `process-failed-campaign-refunds(campaign-id)`

Emergency function to mark failed campaigns and enable refunds if not finalized automatically.

---

## 📖 Error Codes

| Code | Description             |
| ---- | ----------------------- |
| 100  | Only owner allowed      |
| 101  | Campaign not found      |
| 102  | Campaign already exists |
| 103  | Deadline has passed     |
| 104  | Funding is still active |
| 105  | Funding failed          |
| 106  | Funding successful      |
| 107  | No contribution found   |
| 108  | Insufficient funds      |
| 109  | Deadline not yet passed |

---

## 🔐 Security Considerations

* **Strict role enforcement**: Only campaign creators can withdraw.
* **STX is held by contract**: Ensures funds are escrowed securely until resolution.
* **Refund protection**: Contributors can always retrieve their funds from failed campaigns.

---

## 🛠 To Deploy

1. Deploy using Clarity-compatible tools (e.g., Clarinet, Stacks CLI).
2. Interact with functions via web UI, scripts, or CLI.
3. Monitor block height to trigger finalization and withdrawal processes.
