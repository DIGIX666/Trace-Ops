const mockTimeline = [
    {
        id: "tx-001",
        timestamp: "2023-10-27T08:45:00Z",
        type: "DECISION",
        author: "Zone2-Operator-Alpha",
        status: "VALIDATED",
        content: {
            action: "Déclenchement Plan ORSEC",
            resources: ["Pompiers", "Police"],
            justification: "Confirmation visuelle de la montée des eaux"
        }
    },
        {
        id: "tx-002",
        timestamp: "2023-10-28T08:45:00Z",
        type: "DECISION",
        author: "Zone2-Operator-Alpha",
        status: "VALIDATED",
        content: {
            action: "Trafic de drogue ??",
            resources: ["Police", "BAC"],
            justification: "Récupération de 10kg de coke"
        }
    },
    {
        id: "tx-003",
        timestamp: "2023-10-28T10:45:00Z",
        type: "DECISION",
        author: "Zone2-Operator-Alpha",
        status: "VALIDATED",
        content: {
            action: "Tchoupi et ces amis",
            resources: ["Tchoupi", "Ziak", "Booba", "Booska p"],
            justification: "Meurtre"
        }
    },
        {
        id: "tx-004",
        timestamp: "2023-10-29T08:45:00Z",
        type: "DECISION",
        author: "Zone2-Operator-Alpha",
        status: "VALIDATED",
        content: {
            action: "Superman vs Batman",
            resources: ["Superman", "Batman"],
            justification: "Confirmation du match UFC"
        }
    },
            {
        id: "tx-005",
        timestamp: "2023-10-30T08:45:00Z",
        type: "DECISION",
        author: "Zone2-Operator-Alpha",
        status: "VALIDATED",
        content: {
            action: "Superman vs Batman",
            resources: ["Superman", "Batman"],
            justification: "Match réussi: victoire Superman"
        }
    },
            {
        id: "tx-006",
        timestamp: "2023-11-01T08:45:00Z",
        type: "DECISION",
        author: "Zone2-Operator-Alpha",
        status: "VALIDATED",
        content: {
            action: "Opération alpha validée",
            resources: ["Alpha"],
            justification: "Alpha est prêt"
        }
    }
];

module.exports = mockTimeline;