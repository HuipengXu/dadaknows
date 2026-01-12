
import json
import os

def merge_localizations():
    xcstrings_path = "/Users/xuhuipeng/Code/dada-knows/DadaKnows/DadaKnows/Resources/Localizable.xcstrings"
    new_localizations_path = "/Users/xuhuipeng/Code/dada-knows/DadaKnows/DadaKnows/Resources/new_localizations_v4.json"

    if not os.path.exists(xcstrings_path) or not os.path.exists(new_localizations_path):
        print("Error: One or both files not found.")
        return

    try:
        with open(xcstrings_path, 'r', encoding='utf-8') as f:
            xcstrings_data = json.load(f)
        
        with open(new_localizations_path, 'r', encoding='utf-8') as f:
            new_data = json.load(f)

        strings = xcstrings_data.get("strings", {})

        for key, values in new_data.items():
            en_val = values["en"]
            zh_val = values["zh"]

            if key not in strings:
                strings[key] = {
                    "extractionState": "manual",
                    "localizations": {
                        "en": {
                            "stringUnit": {
                                "state": "translated",
                                "value": en_val
                            }
                        },
                        "zh-Hans": {
                            "stringUnit": {
                                "state": "translated",
                                "value": zh_val
                            }
                        }
                    }
                }
            else:
                # Update existing if needed (optional, here we overwrite/ensure translation matches)
                if "localizations" not in strings[key]:
                    strings[key]["localizations"] = {}
                
                strings[key]["localizations"]["en"] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": en_val
                    }
                }
                strings[key]["localizations"]["zh-Hans"] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": zh_val
                    }
                }
        
        xcstrings_data["strings"] = strings

        with open(xcstrings_path, 'w', encoding='utf-8') as f:
            json.dump(xcstrings_data, f, indent=2, ensure_ascii=False)
            f.write('\n') # Add newline at end of file

        print("Successfully merged localizations.")

    except Exception as e:
        print(f"Error merging files: {e}")

if __name__ == "__main__":
    merge_localizations()
