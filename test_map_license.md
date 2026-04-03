flowchart TD
    subgraph Enterprise["🏢 Enterprise Customer (test-multi-enterprise)"]
        ECU["EnterpriseCustomerUser\n(Alice / Bob / Carol / Dave / Eve)"]
    end

    subgraph LicenseManager["📋 License Manager"]
        SP1["SubscriptionPlan\n'Leadership Training'\nexpires 2026-06-25"]
        SP2["SubscriptionPlan\n'Technical Training'\nexpires 2026-09-23"]
        SP3["SubscriptionPlan\n'Compliance Training'\nexpires 2027-03-27"]
        SP4["SubscriptionPlan\n'Data Science'\nexpires 2026-09-23"]
        SP5["SubscriptionPlan\n'Business Skills'\nexpires 2026-07-25"]

        L1["License 807a65cd\nstatus: activated\nactivation_date: 2024-01-15\nuser: Alice ← WINNER"]
        L2["License 807bba77\nstatus: activated\nactivation_date: 2024-03-10\nuser: Alice"]
        L3["License 807bbd3e\nstatus: activated\nactivation_date: 2024-06-01\nuser: Alice"]

        SP1 -- "1 seat per learner" --> L1
        SP2 --> L2
        SP3 --> L3
    end

    subgraph Catalog["📚 Enterprise Catalog Service"]
        C1["Catalog 11111111\n(Leadership)"]
        C2["Catalog 22222222\n(Technical)"]
        C3["Catalog 33333333\n(Compliance)"]
        C4["Catalog 44444444\n(Data Science)"]
        C5["Catalog 55555555\n(Business Skills)"]

        CRS1["Course A\ncourse-v1:edX+Lead+2024"]
        CRS2["Course B\ncourse-v1:edX+Tech+2024"]
        CRS3["Course C\ncourse-v1:edX+Comp+2024"]
        CRS4["Course D\ncourse-v1:edX+Data+2024"]
        CRS5["Course E\ncourse-v1:edX+Biz+2024"]

        C1 -- "contains" --> CRS1
        C2 -- "contains" --> CRS2
        C3 -- "contains" --> CRS3
        C4 -- "contains" --> CRS4
        C5 -- "contains" --> CRS5
    end

    SP1 -- "enterprise_catalog_uuid" --> C1
    SP2 -- "enterprise_catalog_uuid" --> C2
    SP3 -- "enterprise_catalog_uuid" --> C3
    SP4 -- "enterprise_catalog_uuid" --> C4
    SP5 -- "enterprise_catalog_uuid" --> C5

    ECU --> L1
    ECU --> L2
    ECU --> L3

    subgraph BFF["⚡ BFF Dashboard Response (flag ON / v2)"]
        SL["subscription_license\n= first-activated WINNER\n→ L1 Leadership 807a65cd"]
        LBC["licenses_by_catalog\n{\n  '11111111': L1,\n  '22222222': L2,\n  '33333333': L3\n}"]
        ACCESS["✅ Learner can enroll in\nany course inside\nCatalogs 11111111, 22222222, 33333333"]
    end

    L1 -- "grants access to" --> C1
    L2 -- "grants access to" --> C2
    L3 -- "grants access to" --> C3

    L1 --> SL
    LBC --> ACCESS
    C1 --> ACCESS
    C2 --> ACCESS
    C3 --> ACCESS
