@IsTest
private class LG_MecoxInSeasonDemoServiceTest {
    @IsTest
    static void setActive_returnsZeroWhenNoMatchingRows() {
        Test.startTest();
        Integer n = LG_MecoxInSeasonDemoService.setPreGenServiceAppointmentsActive(true);
        Test.stopTest();
        System.assertEquals(0, n);
    }

    @IsTest
    static void applySwimDate_returnsZeroWhenNoMatchingRows() {
        Test.startTest();
        Integer n = LG_MecoxInSeasonDemoService.applyPreGenSwimDateVisibility(Date.newInstance(2026, 5, 20));
        Test.stopTest();
        System.assertEquals(0, n);
    }
}
