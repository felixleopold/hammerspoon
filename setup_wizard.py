import sys
import json
import os
import logging

logging.basicConfig(filename='/tmp/setup_wizard.log', level=logging.DEBUG)

try:
    from PyQt6.QtWidgets import (QApplication, QMainWindow, QTabWidget, QVBoxLayout, QWidget,
                                 QFormLayout, QLineEdit, QPushButton, QLabel, QScrollArea, QMessageBox,
                                 QComboBox, QHBoxLayout, QListWidget, QListWidgetItem, QDialog, QStackedWidget)
    from PyQt6.QtCore import Qt, QSize
    from PyQt6.QtGui import QIcon, QPixmap, QMovie, QFontDatabase, QFont
except ImportError as e:
    logging.error(f"Failed to import PyQt6: {e}")
    print(f"Failed to import PyQt6: {e}", file=sys.stderr)
    sys.exit(1)

# Update the DEFAULT_CONFIG to include the 'fabric' key
DEFAULT_CONFIG = {
    "applications": {
        "Cursor": "Cursor",
        "Editor": "Visual Studio Code",
        "Finder": "Finder",
        "Mail": "Mail",
        "Obsidian": "Obsidian",
        "PrimaryBrowser": "Zen Browser",
        "SecondaryBrowser": "Arc",
        "Spotify": "Spotify",
        "SystemSettings": "System Settings",
        "Terminal": "Warp",
        "WhatsApp": "WhatsApp"
    },
    "folders": {
        "Applications": "/Applications",
        "Desktop": "~/Desktop",
        "Documents": "~/Documents",
        "Downloads": "~/Downloads",
        "Home": "~",
        "Obsidian": "~/Library/Mobile Documents/iCloud~md~obsidian/Documents",
        "School": "~/Documents/Radboud"
    },
    "shortcuts": {
        "appShortcuts": {
            "Cursor": ["ctrl", "alt", "cmd", "C"],
            "Editor": ["ctrl", "alt", "cmd", "V"],
            "Finder": ["ctrl", "alt", "cmd", "F"],
            "Mail": ["ctrl", "alt", "cmd", "M"],
            "Obsidian": ["ctrl", "alt", "cmd", "O"],
            "PrimaryBrowser": ["ctrl", "alt", "cmd", "Z"],
            "SecondaryBrowser": ["ctrl", "alt", "cmd", "A"],
            "Spotify": ["ctrl", "alt", "cmd", "S"],
            "SystemSettings": ["ctrl", "alt", "cmd", "P"],
            "Terminal": ["ctrl", "alt", "cmd", "T"],
            "WhatsApp": ["ctrl", "alt", "cmd", "W"]
        },
        "folderShortcuts": {
            "applications": ["cmd", "shift", "A"],
            "desktop": ["cmd", "shift", "D"],
            "documents": ["cmd", "shift", "F"],
            "downloads": ["cmd", "shift", "L"],
            "home": ["cmd", "shift", "H"],
            "obsidian": ["cmd", "shift", "O"],
            "school": ["cmd", "shift", "R"]
        },
        "general": {
            "copyUrl": ["cmd", "shift", "C"],
            "setupWizard": ["ctrl", "alt", "cmd", "shift", "S"]
        },
        "windowManagement": {
            "bottomHalf": ["alt", "S"],
            "center": ["alt", "C"],
            "fullScreen": ["alt", "F"],
            "leftHalf": ["alt", "A"],
            "leftScreen": ["ctrl", "alt", "A"],
            "loadLayout": ["alt", "cmd", "L"],
            "nextWindow": ["alt", "E"],
            "previousWindow": ["alt", "Q"],
            "rightHalf": ["alt", "D"],
            "rightScreen": ["ctrl", "alt", "D"],
            "saveLayout": ["alt", "cmd", "S"],
            "topHalf": ["alt", "W"]
        }
    },
    "windowManagement": {
        "animationDuration": 0.0
    },
    "fabric": {
        "models": {
            "default": "gpt-4o-mini",
            "model1": "gpt-4o",
            "model2": "llama-3.2-90b-text-preview"
        },
        "patternModels": {
            "correct": "default",
            "general": "model2",
            "improve": "default",
            "latex": "default",
            "latexPlus": "default",
            "noteName": "default",
            "overview": "default",
            "translate": "default"
        }
    }
}

class SetupWizard(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Hammerspoon Setup Wizard")
        self.setGeometry(100, 100, 900, 700)

        # Set the application icon
        icon_path = os.path.expanduser("~/.hammerspoon/hammerspoon_icon.icns")
        if os.path.exists(icon_path):
            self.setWindowIcon(QIcon(icon_path))

        # Set up JetBrains Mono font
        font_id = QFontDatabase.addApplicationFont(os.path.expanduser("~/Library/Fonts/JetBrainsMono-Light.ttf"))
        if font_id != -1:
            font_family = QFontDatabase.applicationFontFamilies(font_id)[0]
            self.font = QFont(font_family)
        else:
            self.font = QFont("Arial")  # Fallback font
        self.font.setPointSize(12)  # Set an appropriate font size

        # Apply the font to the application
        QApplication.setFont(self.font)

        main_widget = QWidget()
        self.setCentralWidget(main_widget)

        layout = QVBoxLayout()
        main_widget.setLayout(layout)

        # Add title and GIF
        title_layout = QHBoxLayout()
        title_layout.addStretch()
        
        title_label = QLabel("Hammerspoon Setup Wizard")
        title_label.setStyleSheet("font-size: 24px; font-weight: bold;")
        title_label.setAlignment(Qt.AlignmentFlag.AlignCenter)
        title_layout.addWidget(title_label)

        gif_label = QLabel()
        movie = QMovie("wizzard.gif")
        movie.setScaledSize(QSize(50, 50))  # Make the GIF smaller
        gif_label.setMovie(movie)
        movie.start()
        title_layout.addWidget(gif_label)
        
        title_layout.addStretch()
        layout.addLayout(title_layout)

        # Create tab buttons
        self.tab_layout = QHBoxLayout()
        self.tab_buttons = []
        tab_names = ["Folders", "Applications", "Shortcuts", "Fabric", "Window Management"]
        for name in tab_names:
            button = QPushButton(name)
            button.setCheckable(True)
            button.clicked.connect(lambda checked, n=name: self.switch_tab(n))
            self.tab_layout.addWidget(button)
            self.tab_buttons.append(button)
        layout.addLayout(self.tab_layout)

        # Create a stacked widget for tab content
        self.stacked_widget = QStackedWidget()
        layout.addWidget(self.stacked_widget)

        self.config = self.load_config()

        self.init_folders_tab()
        self.init_applications_tab()
        self.init_shortcuts_tab()
        self.init_fabric_tab()
        self.init_window_management_tab()

        save_button = QPushButton("Save Configuration")
        save_button.clicked.connect(self.save_configuration)
        layout.addWidget(save_button)

        close_button = QPushButton("Close")
        close_button.clicked.connect(self.close)
        layout.addWidget(close_button)

        self.switch_tab("Folders")  # Start with the Folders tab

        self.setStyleSheet("""
            QMainWindow {
                background-color: #F0F0F0;
            }
            QWidget {
                background-color: white;
            }
            QScrollArea {
                border: none;
                background-color: transparent;
            }
            QScrollBar {
                width: 0px;
                height: 0px;
            }
            QLineEdit, QComboBox {
                padding: 5px;
                border: 1px solid #C0C0C0;
                border-radius: 4px;
                font-family: 'JetBrains Mono', Arial;
                min-width: 250px;  /* Increase the minimum width of input boxes */
            }
            QPushButton {
                background-color: #E0E0E0;
                color: #333333;
                padding: 10px;
                border: none;
                border-top-left-radius: 4px;
                border-top-right-radius: 4px;
                font-family: 'JetBrains Mono', Arial;
            }
            QPushButton:hover {
                background-color: #D0D0D0;
            }
            QPushButton:checked {
                background-color: #F8F8F8;
                border-bottom: 2px solid #007AFF;
            }
            QStackedWidget {
                background-color: white;
                border-top: 1px solid #C0C0C0;
            }
            QLabel {
                font-family: 'JetBrains Mono', Arial;
            }
        """)

    def switch_tab(self, tab_name):
        index = ["Folders", "Applications", "Shortcuts", "Fabric", "Window Management"].index(tab_name)
        self.stacked_widget.setCurrentIndex(index)
        for button in self.tab_buttons:
            button.setChecked(button.text() == tab_name)
        
        # Adjust tab button styling to flow into the page
        for i, button in enumerate(self.tab_buttons):
            if button.isChecked():
                button.setStyleSheet("""
                    background-color: #F8F8F8;
                    border-bottom: 2px solid #007AFF;
                """)
            else:
                button.setStyleSheet("""
                    background-color: #E0E0E0;
                    border-bottom: 1px solid #C0C0C0;
                """)

    def load_config(self):
        config_path = os.path.expanduser("~/.hammerspoon/user_config.json")
        with open(config_path, 'r') as f:
            return json.load(f)

    def reset_to_default(self):
        reply = QMessageBox.question(self, 'Reset Configuration', 
                                     "Are you sure you want to reset all settings to default?",
                                     QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No, 
                                     QMessageBox.StandardButton.No)
        
        if reply == QMessageBox.StandardButton.Yes:
            # Reset the configuration to default
            self.config = DEFAULT_CONFIG.copy()
            
            # Update all input fields with the default values
            self.update_ui_from_config()
            
            # Save the default configuration
            self.save_configuration(show_message=False)
            
            QMessageBox.information(self, "Reset Complete", "Configuration has been reset to default. Please review the changes in each tab.")

    def update_ui_from_config(self):
        # Update folders
        for folder, input_field in self.folder_inputs.items():
            input_field.setText(self.config['folders'].get(folder, ''))

        # Update applications
        for app, input_field in self.app_inputs.items():
            input_field.setText(self.config['applications'].get(app, ''))

        # Update shortcuts
        for key, input_field in self.shortcut_inputs.items():
            category, action = key.split('.')
            if category == 'folderShortcuts':
                action = action.lower()
            shortcut = self.config['shortcuts'][category].get(action, [])
            input_field.setText(','.join(shortcut))

        # Update Fabric
        for model, input_field in self.fabric_inputs['models'].items():
            input_field.setText(self.config['fabric']['models'].get(model, ''))
        for pattern, input_field in self.fabric_inputs['patternModels'].items():
            model = self.config['fabric']['patternModels'].get(pattern, '')
            index = input_field.findText(model)
            if index >= 0:
                input_field.setCurrentIndex(index)

        # Update window management
        for setting, input_field in self.window_management_inputs.items():
            input_field.setText(str(self.config['windowManagement'].get(setting, '')))

    def init_folders_tab(self):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        folders_widget = QWidget()
        scroll.setWidget(folders_widget)
        self.stacked_widget.addWidget(scroll)

        layout = QFormLayout()
        folders_widget.setLayout(layout)

        self.folder_inputs = {}
        for folder, path in self.config['folders'].items():
            self.folder_inputs[folder] = QLineEdit(path)
            layout.addRow(folder, self.folder_inputs[folder])

    def init_applications_tab(self):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        apps_widget = QWidget()
        scroll.setWidget(apps_widget)
        self.stacked_widget.addWidget(scroll)

        layout = QFormLayout()
        apps_widget.setLayout(layout)

        self.app_inputs = {}
        for app, name in sorted(self.config['applications'].items()):
            if app.lower() not in [key.lower() for key in self.app_inputs]:
                self.app_inputs[app] = QLineEdit(name)
                layout.addRow(app, self.app_inputs[app])

    def init_shortcuts_tab(self):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        shortcuts_widget = QWidget()
        scroll.setWidget(shortcuts_widget)
        self.stacked_widget.addWidget(scroll)

        layout = QVBoxLayout()
        shortcuts_widget.setLayout(layout)

        form_layout = QFormLayout()
        form_layout.setAlignment(Qt.AlignmentFlag.AlignHCenter)
        form_layout.setFormAlignment(Qt.AlignmentFlag.AlignHCenter)
        form_layout.setLabelAlignment(Qt.AlignmentFlag.AlignRight)

        self.shortcut_inputs = {}
        
        # Application shortcuts
        form_layout.addRow(QLabel("<b>Application Shortcuts</b>"))
        for app, shortcut in sorted(self.config['shortcuts']['appShortcuts'].items()):
            self.shortcut_inputs[f"appShortcuts.{app}"] = QLineEdit(','.join(shortcut))
            form_layout.addRow(app, self.shortcut_inputs[f"appShortcuts.{app}"])

        # Folder shortcuts
        form_layout.addRow(QLabel("<b>Folder Shortcuts</b>"))
        for folder, shortcut in sorted(self.config['shortcuts']['folderShortcuts'].items()):
            self.shortcut_inputs[f"folderShortcuts.{folder}"] = QLineEdit(','.join(shortcut))
            form_layout.addRow(folder, self.shortcut_inputs[f"folderShortcuts.{folder}"])

        # Window management shortcuts
        form_layout.addRow(QLabel("<b>Window Management Shortcuts</b>"))
        for action, shortcut in sorted(self.config['shortcuts']['windowManagement'].items()):
            self.shortcut_inputs[f"windowManagement.{action}"] = QLineEdit(','.join(shortcut))
            form_layout.addRow(action, self.shortcut_inputs[f"windowManagement.{action}"])

        # General shortcuts
        form_layout.addRow(QLabel("<b>General Shortcuts</b>"))
        for action, shortcut in sorted(self.config['shortcuts']['general'].items()):
            self.shortcut_inputs[f"general.{action}"] = QLineEdit(','.join(shortcut))
            form_layout.addRow(action, self.shortcut_inputs[f"general.{action}"])

        layout.addLayout(form_layout)
        layout.addStretch(1)  # This pushes the form to the top

    def init_fabric_tab(self):
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        fabric_widget = QWidget()
        scroll.setWidget(fabric_widget)
        self.stacked_widget.addWidget(scroll)

        layout = QFormLayout()
        fabric_widget.setLayout(layout)

        self.fabric_inputs = {
            'models': {},
            'patternModels': {}
        }

        layout.addRow(QLabel("<b>Models</b>"))
        for model, value in self.config['fabric']['models'].items():
            self.fabric_inputs['models'][model] = QLineEdit(value)
            layout.addRow(model, self.fabric_inputs['models'][model])

        layout.addRow(QLabel("<b>Pattern Models</b>"))
        for pattern, model in self.config['fabric']['patternModels'].items():
            self.fabric_inputs['patternModels'][pattern] = QComboBox()
            self.fabric_inputs['patternModels'][pattern].addItems(self.config['fabric']['models'].keys())
            self.fabric_inputs['patternModels'][pattern].setCurrentText(model)
            layout.addRow(pattern, self.fabric_inputs['patternModels'][pattern])

    def init_window_management_tab(self):
        window_management_widget = QWidget()
        self.stacked_widget.addWidget(window_management_widget)

        layout = QFormLayout()
        window_management_widget.setLayout(layout)

        self.window_management_inputs = {}
        for setting, value in self.config['windowManagement'].items():
            self.window_management_inputs[setting] = QLineEdit(str(value))
            layout.addRow(setting, self.window_management_inputs[setting])

    def save_configuration(self):
        updated_config = self.config.copy()

        # Update folders
        for folder, input_field in self.folder_inputs.items():
            updated_config['folders'][folder] = input_field.text()

        # Update applications
        updated_config['applications'] = {}
        for app, input_field in self.app_inputs.items():
            updated_config['applications'][app] = input_field.text()

        # Update shortcuts
        for key, input_field in self.shortcut_inputs.items():
            category, action = key.split('.')
            updated_config['shortcuts'][category][action] = input_field.text().split(',')

        # Update Fabric
        for model, input_field in self.fabric_inputs['models'].items():
            updated_config['fabric']['models'][model] = input_field.text()
        for pattern, input_field in self.fabric_inputs['patternModels'].items():
            updated_config['fabric']['patternModels'][pattern] = input_field.currentText()

        # Update window management
        for setting, input_field in self.window_management_inputs.items():
            updated_config['windowManagement'][setting] = float(input_field.text())

        # Save updated configuration to user_config.json
        config_path = os.path.expanduser("~/.hammerspoon/user_config.json")
        try:
            with open(config_path, 'w') as f:
                json.dump(updated_config, f, indent=2, sort_keys=True)
            print(f"Configuration saved to {config_path}")
            
            # Create a temporary file to trigger Hammerspoon reload
            temp_path = os.path.expanduser("~/.hammerspoon/temp_config.json")
            with open(temp_path, 'w') as f:
                json.dump({"reload": True}, f)
            
            QMessageBox.information(self, "Success", "Configuration saved. Hammerspoon will now reload.")
        except Exception as e:
            print(f"Error saving configuration: {e}")
            QMessageBox.warning(self, "Error", f"Failed to save configuration: {e}")

        # Also update the current configuration
        self.config = updated_config

if __name__ == '__main__':
    app = QApplication(sys.argv)
    
    # Set the application icon for the dock
    icon_path = os.path.expanduser("~/.hammerspoon/hammerspoon_icon.icns")
    if os.path.exists(icon_path):
        app.setWindowIcon(QIcon(icon_path))
    
    wizard = SetupWizard()
    wizard.show()
    sys.exit(app.exec())
