// Rather than failing, we choose to just return an empty string if things are messed up.
async function getCurrentUrlInner() {
    console.log("Getting URL");
    var b = chrome ?? firefox ?? browser;
    if (b === null || b === undefined) {
        console.log(`browser is ${b}`);
        return "";
    }
    var w = await b.windows.getCurrent();
    if (w === null || w === undefined) {
        console.log(`window is ${w}`);
        return "";
    } 
    const tabs = await b.tabs.query({ active: true, windowId: w.id });
    if (tabs.length == 0) {
        console.log(`tabs is empty`);
        return "";
    } 
    if (tabs[0].url === null || tabs[0].url === undefined) {
        console.log(`tabs[0].url is ${tabs[0].url}`);
        return "";
    }
    console.log("Successfully got URL");
    return tabs[0].url;
}

console.log("Loaded get_current_url.js");

