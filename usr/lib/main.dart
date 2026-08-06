import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

void main() {
  runApp(const RescisaoApp());
}

class RescisaoApp extends StatelessWidget {
  const RescisaoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cálculo de Rescisão',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const CalculadoraScreen(),
      },
    );
  }
}

class CalculadoraScreen extends StatefulWidget {
  const CalculadoraScreen({super.key});

  @override
  State<CalculadoraScreen> createState() => _CalculadoraScreenState();
}

class _CalculadoraScreenState extends State<CalculadoraScreen> {
  final _formKey = GlobalKey<FormState>();
  final _salarioController = TextEditingController();
  final _comissaoController = TextEditingController();
  
  DateTime? _dataAdmissao;
  DateTime? _dataDemissao;
  String _motivo = 'Sem Justa Causa';
  bool _avisoIndenizado = true;
  bool _feriasVencidas = false;
  int _diasTrabalhadosMes = 30;

  List<Map<String, dynamic>> _resultado = [];
  double _total = 0.0;

  void _calcular() {
    if (!_formKey.currentState!.validate() || _dataAdmissao == null || _dataDemissao == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Preencha todos os campos corretamente.')),
      );
      return;
    }

    double salario = double.tryParse(_salarioController.text.replaceAll(',', '.')) ?? 0;
    double comissao = double.tryParse(_comissaoController.text.replaceAll(',', '.')) ?? 0;
    double baseCalculo = salario + comissao;

    _resultado.clear();
    _total = 0;

    // 1. Saldo de Salário
    double saldoSalario = (baseCalculo / 30) * _diasTrabalhadosMes;
    _addRubrica('Saldo de Salário ($_diasTrabalhadosMes dias)', saldoSalario, 
        'Calculado sobre o salário base + média de comissões, proporcional aos dias trabalhados no mês da rescisão.');

    // 2. Aviso Prévio
    if (_motivo == 'Sem Justa Causa' && _avisoIndenizado) {
      int anos = _dataDemissao!.year - _dataAdmissao!.year;
      if (_dataDemissao!.month < _dataAdmissao!.month || (_dataDemissao!.month == _dataAdmissao!.month && _dataDemissao!.day < _dataAdmissao!.day)) {
        anos--;
      }
      int diasAviso = 30 + (anos * 3);
      if (diasAviso > 90) diasAviso = 90;

      double valorAviso = (baseCalculo / 30) * diasAviso;
      _addRubrica('Aviso Prévio Indenizado ($diasAviso dias)', valorAviso, 
          '30 dias base + 3 dias por ano completo trabalhado. A média de comissões integra a base de cálculo.');
    }

    // 3. 13º Salário Proporcional
    int meses13 = _dataDemissao!.month;
    if (_dataDemissao!.day < 15) meses13--;
    if (_motivo == 'Sem Justa Causa' && _avisoIndenizado) {
       // Projeção do aviso prévio
       meses13++; // Simplificação para 1 mês de projeção
       if (meses13 > 12) meses13 = 12;
    }
    double valor13 = (baseCalculo / 12) * meses13;
    _addRubrica('13º Salário Proporcional ($meses13/12)', valor13, 
        'Proporcional aos meses trabalhados no ano (fração >= 15 dias). Base inclui salário e média de comissões.');

    // 4. Férias Vencidas
    if (_feriasVencidas) {
      double feriasV = baseCalculo + (baseCalculo / 3);
      _addRubrica('Férias Vencidas + 1/3', feriasV, 
          'Devidas quando completado o período aquisitivo de 1 ano sem gozo. A comissão integra a base.');
    }

    // 5. Férias Proporcionais
    int mesesFerias = 0; // Cálculo simplificado de meses proporcionais
    int diasDif = _dataDemissao!.difference(_dataAdmissao!).inDays % 365;
    mesesFerias = (diasDif / 30).floor();
    if ((diasDif % 30) >= 15) mesesFerias++;
    
    if (_motivo == 'Sem Justa Causa' && _avisoIndenizado) {
      mesesFerias++; // Projeção
    }
    if (mesesFerias > 12) mesesFerias = 12;

    double valorFeriasP = (baseCalculo / 12) * mesesFerias;
    double tercoFeriasP = valorFeriasP / 3;
    _addRubrica('Férias Proporcionais ($mesesFerias/12) + 1/3', valorFeriasP + tercoFeriasP, 
        'Proporcional ao período aquisitivo incompleto + projeção do aviso. Adicional de 1/3 constitucional aplicado sobre salário + comissões.');

    // 6. Multa 40% FGTS (Simplificado: 8% do baseCalculo * meses totais)
    if (_motivo == 'Sem Justa Causa') {
      int totalMeses = (_dataDemissao!.difference(_dataAdmissao!).inDays / 30).floor();
      double saldoFgtsEstimado = (baseCalculo * 0.08) * totalMeses;
      double multa40 = saldoFgtsEstimado * 0.40;
      _addRubrica('Multa 40% FGTS (Estimativa)', multa40, 
          'Calculada sobre o saldo total do FGTS depositado durante o contrato (incluindo sobre as comissões mensais).');
    }

    setState(() {});
  }

  void _addRubrica(String nome, double valor, String justificativa) {
    _resultado.add({
      'nome': nome,
      'valor': valor,
      'justificativa': justificativa
    });
    _total += valor;
  }

  Future<void> _selectDate(BuildContext context, bool isAdmissao) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        if (isAdmissao) _dataAdmissao = picked;
        else _dataDemissao = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');
    final dateFormat = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Cálculo de Rescisão')),
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Formulário
          Expanded(
            flex: 1,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Dados do Contrato', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(_dataAdmissao == null ? 'Selecionar Data de Admissão' : 'Admissão: ${dateFormat.format(_dataAdmissao!)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context, true),
                    ),
                    ListTile(
                      title: Text(_dataDemissao == null ? 'Selecionar Data de Demissão' : 'Demissão: ${dateFormat.format(_dataDemissao!)}'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectDate(context, false),
                    ),
                    TextFormField(
                      controller: _salarioController,
                      decoration: const InputDecoration(labelText: 'Salário Base (R\$)'),
                      keyboardType: TextInputType.number,
                      validator: (val) => val == null || val.isEmpty ? 'Informe o salário' : null,
                    ),
                    TextFormField(
                      controller: _comissaoController,
                      decoration: const InputDecoration(labelText: 'Média de Comissões (R\$)'),
                      keyboardType: TextInputType.number,
                    ),
                    TextFormField(
                      decoration: const InputDecoration(labelText: 'Dias trabalhados no mês da rescisão'),
                      keyboardType: TextInputType.number,
                      initialValue: '30',
                      onChanged: (val) => _diasTrabalhadosMes = int.tryParse(val) ?? 30,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _motivo,
                      decoration: const InputDecoration(labelText: 'Motivo da Rescisão'),
                      items: ['Sem Justa Causa', 'Pedido de Demissão'].map((String v) {
                        return DropdownMenuItem(value: v, child: Text(v));
                      }).toList(),
                      onChanged: (val) {
                        setState(() { _motivo = val!; });
                      },
                    ),
                    SwitchListTile(
                      title: const Text('Aviso Prévio Indenizado'),
                      value: _avisoIndenizado,
                      onChanged: _motivo == 'Sem Justa Causa' ? (val) => setState(() => _avisoIndenizado = val) : null,
                    ),
                    SwitchListTile(
                      title: const Text('Possui Férias Vencidas?'),
                      value: _feriasVencidas,
                      onChanged: (val) => setState(() => _feriasVencidas = val),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _calcular,
                      child: const Text('Calcular Rescisão'),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Resultado
          Expanded(
            flex: 1,
            child: Container(
              color: Colors.grey[100],
              padding: const EdgeInsets.all(16.0),
              child: _resultado.isEmpty 
                  ? const Center(child: Text('Preencha os dados e clique em Calcular.'))
                  : ListView(
                      children: [
                        const Text('Demonstrativo de Rescisão', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ..._resultado.map((r) => Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text(r['nome'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                                    Text(currencyFormat.format(r['valor']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(r['justificativa'], style: TextStyle(color: Colors.grey[700], fontSize: 13)),
                              ],
                            ),
                          ),
                        )),
                        const Divider(thickness: 2),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('TOTAL BRUTO ESTIMADO', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                              Text(currencyFormat.format(_total), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue[800])),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text('* Nota sobre as Comissões: De acordo com a Súmula 27 do TST, as comissões integram o salário para todos os fins legais. Portanto, a média das comissões recebidas foi somada ao salário base para compor a base de cálculo de todas as verbas rescisórias acima (Aviso, 13º, Férias e FGTS).',
                          style: TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                        ),
                      ],
                    ),
            ),
          )
        ],
      ),
    );
  }
}
