import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:silkplayer/providers/enums/BackEndConfigs.dart';
import 'package:silkplayer/providers/enums/VideoBackend.dart';

class BackendConfigurationSelector extends ConsumerWidget {
  const BackendConfigurationSelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentBackend = ref.watch(videoBackendProvider);
    final pipedInstance = ref.watch(pipedInstanceProvider);
    final invidiousInstance = ref.watch(invidiousInstanceProvider);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.white.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          _buildBackendSelector(context, ref, currentBackend),
          if (currentBackend == VideoBackend.piped ||
              currentBackend == VideoBackend.beast)
            _buildInstanceSection(
              context,
              ref,
              'Piped Instance',
              pipedInstance,
              Icons.api_outlined,
              Colors.blue,
              () => _showInstanceSelector(context, ref, isPiped: true),
            ),
          if (currentBackend == VideoBackend.invidious ||
              currentBackend == VideoBackend.beast)
            _buildInstanceSection(
              context,
              ref,
              'Invidious Instance',
              invidiousInstance,
              Icons.cloud_outlined,
              Colors.purple,
              () => _showInstanceSelector(context, ref, isPiped: false),
            ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade900, Colors.black],
        ),
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.grey.shade800,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade700, width: 1),
            ),
            child: Icon(
              Icons.settings_input_component_outlined,
              size: 22,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Backend Configuration',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Choose your preferred video server',
                  style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackendSelector(
    BuildContext context,
    WidgetRef ref,
    VideoBackend currentBackend,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey.shade900,
        border: Border.all(color: Colors.grey.shade700, width: 1),
      ),
      child: DropdownButtonFormField<VideoBackend>(
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          prefixIcon: Icon(Icons.tune, color: Colors.white, size: 20),
        ),
        value: currentBackend,
        dropdownColor: Colors.grey.shade900,
        style: TextStyle(color: Colors.white, fontSize: 16),
        items: VideoBackend.values.map((backend) {
          return DropdownMenuItem(
            value: backend,
            child: Text(
              _getBackendName(backend),
              style: TextStyle(color: Colors.white),
            ),
          );
        }).toList(),
        onChanged: (backend) {
          if (backend != null) {
            ref.read(videoBackendProvider.notifier).state = backend;
          }
        },
      ),
    );
  }

  Widget _buildInstanceSection(
    BuildContext context,
    WidgetRef ref,
    String title,
    String instance,
    IconData icon,
    Color accentColor,
    VoidCallback onTap,
  ) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey.shade900,
              border: Border.all(color: Colors.grey.shade700, width: 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Icon(icon, color: accentColor, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        instance
                            .replaceFirst('https://', '')
                            .replaceFirst('http://', ''),
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                FutureBuilder<bool>(
                  future: _checkInstanceHealth(
                    instance,
                    title.contains('Piped'),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        ),
                      );
                    }

                    final isHealthy = snapshot.data ?? false;
                    return Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: (isHealthy ? Colors.green : Colors.red)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: (isHealthy ? Colors.green : Colors.red)
                              .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Icon(
                        isHealthy
                            ? Icons.check_circle_outline
                            : Icons.error_outline,
                        color: isHealthy ? Colors.green : Colors.red,
                        size: 14,
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey.shade500,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showInstanceSelector(
    BuildContext context,
    WidgetRef ref, {
    required bool isPiped,
  }) {
    final currentInstance = isPiped
        ? ref.watch(pipedInstanceProvider)
        : ref.watch(invidiousInstanceProvider);
    final instances = isPiped
        ? BackendConfig.pipedInstances
        : BackendConfig.invidiousInstances;

    final controller = TextEditingController();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          maxChildSize: 0.9,
          minChildSize: 0.5,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border.all(color: Colors.grey.shade800, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.3),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade600,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isPiped ? Colors.blue : Colors.purple)
                                .withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: (isPiped ? Colors.blue : Colors.purple)
                                  .withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            isPiped ? Icons.api_outlined : Icons.cloud_outlined,
                            color: isPiped ? Colors.blue : Colors.purple,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Select ${isPiped ? 'Piped' : 'Invidious'} Instance',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: instances.length,
                      itemBuilder: (context, index) {
                        final instance = instances[index];
                        return _buildInstanceListTile(
                          context,
                          ref,
                          instance,
                          currentInstance,
                          isPiped,
                        );
                      },
                    ),
                  ),
                  _buildCustomInstanceInput(context, ref, controller, isPiped),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInstanceListTile(
    BuildContext context,
    WidgetRef ref,
    String instance,
    String currentInstance,
    bool isPiped,
  ) {
    final isSelected = instance == currentInstance;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? Colors.white : Colors.grey.shade700,
          width: isSelected ? 2 : 1,
        ),
        color: isSelected ? Colors.grey.shade900 : Colors.grey.shade800,
      ),
      child: FutureBuilder<bool>(
        future: _checkInstanceHealth(instance, isPiped),
        builder: (context, snapshot) {
          final isHealthy = snapshot.data ?? false;
          final isLoading = snapshot.connectionState == ConnectionState.waiting;

          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            title: Text(
              instance.replaceFirst('https://', '').replaceFirst('http://', ''),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                color: Colors.white,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      instance,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isLoading)
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: (isHealthy ? Colors.green : Colors.red)
                            .withOpacity(0.2),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: (isHealthy ? Colors.green : Colors.red)
                              .withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isHealthy ? Icons.check_circle : Icons.error,
                            color: isHealthy ? Colors.green : Colors.red,
                            size: 12,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isHealthy ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 10,
                              color: isHealthy ? Colors.green : Colors.red,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            trailing: isSelected
                ? Icon(Icons.check_circle, color: Colors.white)
                : null,
            onTap: () {
              if (isPiped) {
                ref.read(pipedInstanceProvider.notifier).state = instance;
              } else {
                ref.read(invidiousInstanceProvider.notifier).state = instance;
              }
              Navigator.pop(context);
            },
          );
        },
      ),
    );
  }

  Widget _buildCustomInstanceInput(
    BuildContext context,
    WidgetRef ref,
    TextEditingController controller,
    bool isPiped,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade800, width: 1)),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            style: TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Custom Instance URL',
              labelStyle: TextStyle(color: Colors.grey.shade400),
              hintText: 'https://your-custom-instance.com',
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.link, color: Colors.grey.shade400),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.white, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey.shade900,
              suffixIcon: Container(
                margin: const EdgeInsets.all(4),
                child: ElevatedButton(
                  onPressed: () {
                    final text = controller.text.trim();
                    if (text.isNotEmpty) {
                      final customInstance = text.startsWith('http')
                          ? text
                          : 'https://$text';
                      if (isPiped) {
                        ref.read(pipedInstanceProvider.notifier).state =
                            customInstance;
                      } else {
                        ref.read(invidiousInstanceProvider.notifier).state =
                            customInstance;
                      }
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Add'),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                foregroundColor: Colors.grey.shade400,
              ),
              child: const Text('Cancel'),
            ),
          ),
        ],
      ),
    );
  }

  Future<bool> _checkInstanceHealth(String instanceUrl, bool isPiped) async {
    try {
      final String endpoint;

      if (isPiped) {
        // Piped API health check
        endpoint = instanceUrl.endsWith('/')
            ? '${instanceUrl}healthcheck'
            : '$instanceUrl/healthcheck';
      } else {
        // Invidious API health check
        endpoint = instanceUrl.endsWith('/')
            ? '${instanceUrl}api/v1/stats'
            : '$instanceUrl/api/v1/stats';
      }

      final response = await http
          .get(
            Uri.parse(endpoint),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'SilkPlayer/1.0',
            },
          )
          .timeout(const Duration(seconds: 5));

      if (isPiped) {
        // For Piped, check if response is 200 and contains expected data
        return response.statusCode == 200;
      } else {
        // For Invidious, check if response is 200 and contains stats data
        return response.statusCode == 200 &&
            response.body.isNotEmpty &&
            response.body.contains('version');
      }
    } catch (e) {
      // Handle specific errors for better debugging
      print('Health check failed for $instanceUrl: $e');
      return false;
    }
  }

  String _getBackendName(VideoBackend backend) {
    switch (backend) {
      case VideoBackend.ytdlp:
        return "YTDLP_piyush";
      case VideoBackend.explode:
        return 'YouTube Explode Servers [Slow]';
      case VideoBackend.piped:
        return 'Piped Servers';
      case VideoBackend.invidious:
        return 'Invidious Servers';
      case VideoBackend.beast:
        return 'Hybrid Mode (Piped + Invidious)';
    }
  }
}
