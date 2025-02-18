# Define Sailfish as it is absent
%if !0%{?fedora}
%define sailfishos 1
%endif

# Prevent brp-python-bytecompile from running.
%define __os_install_post %{___build_post}

%if 0%{?sailfishos}
# "Harbour RPM packages should not provide anything."
%define __provides_exclude_from ^%{_datadir}/.*$
%define __requires_exclude ^libs2.*$
%endif

%if 0%{?sailfishos}
Name: harbour-pure-maps
%else
Name: pure-maps
%endif

Version: 2.4.1
Release: 1

Summary: Maps and navigation
License: GPLv3+
URL:     https://github.com/rinigus/pure-maps
Source:  %{name}-%{version}.tar.xz
Source1: apikeys.py
%if 0%{?sailfishos}
Source101:  harbour-pure-maps-rpmlintrc
%endif

BuildRequires: gettext
BuildRequires: make
BuildRequires: python(abi) > 3
BuildRequires: pkgconfig(Qt5Core)
BuildRequires: pkgconfig(Qt5Qml)
BuildRequires: pkgconfig(Qt5Quick)
BuildRequires: pkgconfig(Qt5Positioning)
BuildRequires: pkgconfig(Qt5DBus)
BuildRequires: s2geometry-devel

Requires: mapboxgl-qml >= 1.7.0

%if 0%{?sailfishos}
BuildRequires: qt5-qttools-linguist
BuildRequires: pkgconfig(sailfishapp) >= 1.0.2
Requires: libkeepalive
Requires: libsailfishapp-launcher
Requires: pyotherside-qml-plugin-python3-qt5 >= 1.5.1
Requires: qt5-qtdeclarative-import-multimedia >= 5.2
Requires: qt5-qtdeclarative-import-positioning >= 5.2
Requires: sailfishsilica-qt5
%else
BuildRequires: qt5-linguist
BuildRequires: cmake(KF5Kirigami2)
BuildRequires: pkgconfig(Qt5QuickControls2)
Requires: kf5-kirigami2
Requires: mapboxgl-qml
Requires: pyotherside
Requires: qt5-qtmultimedia
Requires: qt5-qtlocation
Requires: mimic
Requires: nemo-qml-plugin-dbus-qt5
Requires: qml-module-clipboard
Requires: dbus-tools
%endif

%description
View maps, find places and routes, navigate with turn-by-turn instructions,
search for nearby places by type and share your location.

%prep
%setup -q
cp %{SOURCE1} tools/
tools/manage-keys inject . || true

%build
%if 0%{?sailfishos}
%qmake5 VERSION='%{version}-%{release}' FLAVOR=silica CONFIG+=install_gpxpy
%else
%qmake5 VERSION='%{version}-%{release}' FLAVOR=kirigami CONFIG+=install_gpxpy
%endif

make %{?_smp_mflags}

%install
make INSTALL_ROOT=%{buildroot} install

%if 0%{?sailfishos}
# ship some shared libraries
mkdir -p %{buildroot}%{_datadir}/%{name}/lib
cp %{_libdir}/libs2.so %{buildroot}%{_datadir}/%{name}/lib

# strip executable bit from all libraries
chmod -x %{buildroot}%{_datadir}/%{name}/lib/*.so*

%endif # sailfishos

%files
%defattr(-,root,root,-)
%{_bindir}/%{name}
%{_datadir}/%{name}
%{_datadir}/applications/%{name}.desktop
%{_datadir}/applications/%{name}-uri-handler.desktop
%{_datadir}/icons/hicolor/*/apps/%{name}.png
%if 0%{?sailfishos}
%exclude %{_datadir}/metainfo/%{name}.appdata.xml
%else
%{_datadir}/metainfo/%{name}.appdata.xml
%endif
