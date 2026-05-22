/**
 * Mecox in-season demo: hand-crafted Work Orders / Service Appointments on the four in-season maintenance plans
 * and visibility toggles for LG_Active__c instead of live generateWorkOrders for in-season plans.
 * Pre-gen Work Orders are scoped by the four in-season MaintenancePlanIds (SuggestedMaintenanceDate required when MP is set).
 */
public with sharing class LG_MecoxInSeasonDemoService {
    public static final Id MECOX_ACCOUNT_ID = Id.valueOf('001fj00001A6meoAAB');
    public static final Id MECOX_SERVICE_CONTRACT_ID = Id.valueOf('810fj0000BLDMnNAQX');
    public static final Id MECOX_SERVICE_TERRITORY_ID = Id.valueOf('0Hhfj000000SVKECA4');

    public static final Id ASSET_POOL_ID = Id.valueOf('02ifj0000020aDdAAI');
    public static final Id ASSET_SPA_ID = Id.valueOf('02ifj0000020aDeAAI');
    public static final Id ASSET_FOUNTAIN_ID = Id.valueOf('02ifj0000020aDfAAI');

    public static final Id PLAN_POOL_WEEKLY_ID = Id.valueOf('1MPfj000002AQXxGAO');
    public static final Id PLAN_POOL_CHEM_ID = Id.valueOf('1MPfj000002AbWbGAK');
    public static final Id PLAN_SPA_WEEKLY_ID = Id.valueOf('1MPfj000002AbWdGAK');
    public static final Id PLAN_FOUNTAIN_ID = Id.valueOf('1MPfj000002AbWeGAK');

    private static final Id WORKTYPE_WEEKLY_ID = Id.valueOf('08qfj0000003fBWAAY');
    private static final Id WORKTYPE_CHEM_ID = Id.valueOf('08qfj0000003fBXAAY');

    private static final Set<Id> IN_SEASON_PLAN_IDS = new Set<Id>{
        PLAN_POOL_WEEKLY_ID,
        PLAN_POOL_CHEM_ID,
        PLAN_SPA_WEEKLY_ID,
        PLAN_FOUNTAIN_ID
    };

    /**
     * Shows or hides all pre-generated in-season Service Appointments (hand-crafted Work Orders only).
     */
    public static Integer setPreGenServiceAppointmentsActive(Boolean active) {
        if (active == null) {
            return 0;
        }
        List<ServiceAppointment> sas = queryPreGenServiceAppointments();
        for (ServiceAppointment sa : sas) {
            sa.LG_Active__c = active;
        }
        if (!sas.isEmpty()) {
            update sas;
        }
        return sas.size();
    }

    /**
     * After a swim-date change: hide SAs before the new swim date; show those on or after it.
     */
    public static Integer applyPreGenSwimDateVisibility(Date newSwimDate) {
        if (newSwimDate == null) {
            return 0;
        }
        List<ServiceAppointment> sas = queryPreGenServiceAppointments();
        for (ServiceAppointment sa : sas) {
            Date occ = sa.EarliestStartTime != null ? sa.EarliestStartTime.date() : null;
            if (occ == null) {
                sa.LG_Active__c = false;
            } else {
                sa.LG_Active__c = occ >= newSwimDate;
            }
        }
        if (!sas.isEmpty()) {
            update sas;
        }
        return sas.size();
    }

    private static List<ServiceAppointment> queryPreGenServiceAppointments() {
        return [
            SELECT Id, EarliestStartTime, LG_Active__c
            FROM ServiceAppointment
            WHERE
                ParentRecordId IN (
                    SELECT Id
                    FROM WorkOrder
                    WHERE MaintenancePlanId IN :IN_SEASON_PLAN_IDS
                )
        ];
    }

    /**
     * One-time seed: 48 Work Orders + auto-created Service Appointments (all LG_Active__c = false).
     * Skips if any matching hand-crafted Work Order already exists.
     */
    public static String seedInSeasonWorkOrdersIfAbsent() {
        Integer existing = (Integer) [
                SELECT COUNT(Id) cnt
                FROM WorkOrder
                WHERE MaintenancePlanId IN :IN_SEASON_PLAN_IDS
            ][0]
            .get('cnt');
        if (existing > 0) {
            return 'Skip: found ' + existing + ' existing Work Order(s) on in-season plans.';
        }

        List<ServiceAppointment> legacy = [
            SELECT Id
            FROM ServiceAppointment
            WHERE AccountId = :MECOX_ACCOUNT_ID
        ];
        for (ServiceAppointment s : legacy) {
            s.LG_Active__c = true;
        }
        if (!legacy.isEmpty()) {
            update legacy;
        }

        List<WorkOrder> toInsert = new List<WorkOrder>();
        addSeries(
            toInsert,
            PLAN_POOL_WEEKLY_ID,
            ASSET_POOL_ID,
            'Pool',
            WORKTYPE_WEEKLY_ID,
            new List<Date>{
                Date.newInstance(2026, 5, 6),
                Date.newInstance(2026, 5, 13),
                Date.newInstance(2026, 5, 20),
                Date.newInstance(2026, 5, 27),
                Date.newInstance(2026, 6, 3),
                Date.newInstance(2026, 6, 10),
                Date.newInstance(2026, 6, 17),
                Date.newInstance(2026, 6, 24),
                Date.newInstance(2026, 7, 1),
                Date.newInstance(2026, 7, 8),
                Date.newInstance(2026, 7, 15),
                Date.newInstance(2026, 7, 22)
            }
        );
        addSeries(
            toInsert,
            PLAN_POOL_CHEM_ID,
            ASSET_POOL_ID,
            'Pool',
            WORKTYPE_CHEM_ID,
            new List<Date>{
                Date.newInstance(2026, 5, 4),
                Date.newInstance(2026, 5, 11),
                Date.newInstance(2026, 5, 18),
                Date.newInstance(2026, 5, 25),
                Date.newInstance(2026, 6, 1),
                Date.newInstance(2026, 6, 8),
                Date.newInstance(2026, 6, 15),
                Date.newInstance(2026, 6, 22),
                Date.newInstance(2026, 6, 29),
                Date.newInstance(2026, 7, 6),
                Date.newInstance(2026, 7, 13),
                Date.newInstance(2026, 7, 20)
            }
        );
        addSeries(
            toInsert,
            PLAN_SPA_WEEKLY_ID,
            ASSET_SPA_ID,
            'Spa',
            WORKTYPE_WEEKLY_ID,
            new List<Date>{
                Date.newInstance(2026, 5, 6),
                Date.newInstance(2026, 5, 13),
                Date.newInstance(2026, 5, 20),
                Date.newInstance(2026, 5, 27),
                Date.newInstance(2026, 6, 3),
                Date.newInstance(2026, 6, 10),
                Date.newInstance(2026, 6, 17),
                Date.newInstance(2026, 6, 24),
                Date.newInstance(2026, 7, 1),
                Date.newInstance(2026, 7, 8),
                Date.newInstance(2026, 7, 15),
                Date.newInstance(2026, 7, 22)
            }
        );
        addSeries(
            toInsert,
            PLAN_FOUNTAIN_ID,
            ASSET_FOUNTAIN_ID,
            'Fountain',
            WORKTYPE_WEEKLY_ID,
            new List<Date>{
                Date.newInstance(2026, 5, 7),
                Date.newInstance(2026, 5, 14),
                Date.newInstance(2026, 5, 21),
                Date.newInstance(2026, 5, 28),
                Date.newInstance(2026, 6, 4),
                Date.newInstance(2026, 6, 11),
                Date.newInstance(2026, 6, 18),
                Date.newInstance(2026, 6, 25),
                Date.newInstance(2026, 7, 2),
                Date.newInstance(2026, 7, 9),
                Date.newInstance(2026, 7, 16),
                Date.newInstance(2026, 7, 23)
            }
        );

        insert toInsert;

        Set<Id> woIds = new Map<Id, WorkOrder>(toInsert).keySet();
        List<ServiceAppointment> sas = [
            SELECT Id, ParentRecordId
            FROM ServiceAppointment
            WHERE ParentRecordId IN :woIds
        ];

        Map<Id, WorkOrder> woById = new Map<Id, WorkOrder>(
            [SELECT Id, StartDate, EndDate FROM WorkOrder WHERE Id IN :woIds]
        );

        for (ServiceAppointment sa : sas) {
            WorkOrder wo = woById.get(sa.ParentRecordId);
            sa.LG_Active__c = false;
            sa.Status = 'None';
            sa.ServiceTerritoryId = MECOX_SERVICE_TERRITORY_ID;
            if (wo != null) {
                sa.EarliestStartTime = wo.StartDate;
                sa.DueDate = wo.EndDate;
            }
        }
        if (!sas.isEmpty()) {
            update sas;
        }

        return 'Inserted ' + toInsert.size() + ' Work Orders; updated ' + sas.size() + ' Service Appointments.';
    }

    private static void addSeries(
        List<WorkOrder> buffer,
        Id maintenancePlanId,
        Id assetId,
        String assetLabel,
        Id workTypeId,
        List<Date> occurrenceDates
    ) {
        for (Date d : occurrenceDates) {
            Datetime startDt = Datetime.newInstance(d.year(), d.month(), d.day(), 7, 0, 0);
            Datetime endDt = workTypeId == WORKTYPE_CHEM_ID ? startDt.addMinutes(30) : startDt.addHours(1);
            WorkOrder wo = new WorkOrder(
                AccountId = MECOX_ACCOUNT_ID,
                AssetId = assetId,
                MaintenancePlanId = maintenancePlanId,
                SuggestedMaintenanceDate = d,
                ServiceContractId = MECOX_SERVICE_CONTRACT_ID,
                WorkTypeId = workTypeId,
                Subject = 'Maintenance Mecox ' + assetLabel + ': ' + formatEnglishDate(d),
                Status = 'New',
                StartDate = startDt,
                EndDate = endDt
            );
            buffer.add(wo);
        }
    }

    private static String formatEnglishDate(Date d) {
        Datetime dt = Datetime.newInstance(d.year(), d.month(), d.day());
        return dt.format('MMMM d, yyyy');
    }
}
