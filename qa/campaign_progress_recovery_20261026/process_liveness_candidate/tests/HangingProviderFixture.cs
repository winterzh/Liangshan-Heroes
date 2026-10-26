// TEST FIXTURE ONLY: no Win32 query, target access, report, or Store interaction.
// The fixed-name executable exercises the unchanged oracle's owned-child timeout.
using System.Threading;
internal static class HangingProviderFixture
{
    private static int Main(string[] args)
    {
        Thread.Sleep(30000);
        return 0;
    }
}
