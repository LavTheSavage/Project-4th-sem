package com.f1soft.esewa.esewa_flutter_sdk

import com.f1soft.esewasdk.EsewaConfiguration
import com.f1soft.esewasdk.EsewaPayment


class PaymentUtils {

    companion object {

        fun initConfig(map: HashMap<String, String>): EsewaConfiguration {
            return EsewaConfiguration(
                clientId = map["client_id"]?:"",
                secretKey = map["client_secret"]?:"",
                environment = map["environment"]?:""
            )
        }

        fun initPayment(map: HashMap<String, String>): EsewaPayment {
            when {
                map["ebp_no"]!=null -> {
                    return EsewaPayment(
                        map["product_price"]?:"",
                        map["product_name"]?:"",
                        map["product_id"]?:"",
                        map["callback_url"]?:"",
                        HashMap<String,String>().apply {
                            put("ebpNo",map["ebp_no"]!!)
                        }
                    )
                }
                else -> {
                    return EsewaPayment(
                        map["product_price"]?:"",
                        map["product_name"]?:"",
                        map["product_id"]?:"",
                        map["callback_url"]?:"",
                    )
                }
            }

        }

    }
}